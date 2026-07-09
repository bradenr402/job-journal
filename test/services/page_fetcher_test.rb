require "test_helper"
require "minitest/mock"

class PageFetcherTest < ActiveSupport::TestCase
  ALLOWED = %w[example.com www.example.com].freeze

  test "safe? rejects unsupported hosts, private hosts, and bad URLs" do
    with_resolution("example.com" => %w[93.184.216.34]) do
      assert PageFetcher.safe?("https://example.com/page", allowed_hosts: ALLOWED)
    end

    assert_not PageFetcher.safe?("https://other.com/page", allowed_hosts: ALLOWED)
    assert_not PageFetcher.safe?("http://example.com/page", allowed_hosts: ALLOWED)
    assert_not PageFetcher.safe?("not a url", allowed_hosts: ALLOWED)

    with_resolution("example.com" => %w[127.0.0.1]) do
      assert_not PageFetcher.safe?("https://example.com/page", allowed_hosts: ALLOWED)
    end
  end

  test "fetch returns the body for an allowed public host" do
    with_resolution("example.com" => %w[93.184.216.34]) do
      with_http_response("<html>ok</html>") do
        assert_equal "<html>ok</html>", PageFetcher.fetch("https://example.com/page", allowed_hosts: ALLOWED)
      end
    end
  end

  test "fetch returns nil on failure while fetch! raises a typed error" do
    Net::HTTP.stub :start, ->(*) { raise "should not be called" } do
      assert_nil PageFetcher.fetch("https://other.com/page", allowed_hosts: ALLOWED)
      assert_raises(PageFetcher::UnsupportedHost) do
        PageFetcher.fetch!("https://other.com/page", allowed_hosts: ALLOWED)
      end
    end
  end

  test "canonicalize rewrites the URL before fetching" do
    requested_paths = []
    canonicalize = ->(uri) { uri.dup.tap { it.path = "/canonical" } }

    with_resolution("example.com" => %w[93.184.216.34]) do
      with_http_response("<html>ok</html>", requested_paths:) do
        PageFetcher.fetch("https://example.com/original", allowed_hosts: ALLOWED, canonicalize:)
      end
    end

    assert_equal [ "/canonical" ], requested_paths
  end

  test "raises AccessBlocked when the host blocks the request" do
    with_resolution("example.com" => %w[93.184.216.34]) do
      with_http_status(Net::HTTPForbidden.new("1.1", "403", "Forbidden")) do
        output = capture_log do
          assert_raises(PageFetcher::AccessBlocked) do
            PageFetcher.fetch!("https://example.com/page", allowed_hosts: ALLOWED)
          end
        end

        assert_match %r{\[PageFetcher\] HTTP 403 Forbidden for https://example.com/page}, output
      end
    end
  end

  test "raises FetchFailed for non-blocking error statuses and still logs" do
    with_resolution("example.com" => %w[93.184.216.34]) do
      with_http_status(Net::HTTPServiceUnavailable.new("1.1", "503", "Service Unavailable")) do
        output = capture_log do
          error = assert_raises(PageFetcher::FetchFailed) do
            PageFetcher.fetch!("https://example.com/page", allowed_hosts: ALLOWED)
          end

          assert_not_kind_of PageFetcher::AccessBlocked, error
        end

        assert_match(/\[PageFetcher\] HTTP 503/, output)
      end
    end
  end

  test "fetch swallows a blocked response but still logs the status code" do
    with_resolution("example.com" => %w[93.184.216.34]) do
      with_http_status(Net::HTTPServiceUnavailable.new("1.1", "503", "Service Unavailable")) do
        output = capture_log do
          assert_nil PageFetcher.fetch("https://example.com/page", allowed_hosts: ALLOWED)
        end

        assert_match(/\[PageFetcher\] HTTP 503/, output)
      end
    end
  end

  test "raises FetchFailed and logs when the request times out" do
    with_resolution("example.com" => %w[93.184.216.34]) do
      Net::HTTP.stub(:start, ->(*, **) { raise Timeout::Error }) do
        output = capture_log do
          assert_raises(PageFetcher::FetchFailed) do
            PageFetcher.fetch!("https://example.com/page", allowed_hosts: ALLOWED)
          end
        end

        assert_match(/\[PageFetcher\] Timed out after \d+s/, output)
      end
    end
  end

  test "raises FetchFailed and logs on a network error" do
    with_resolution("example.com" => %w[93.184.216.34]) do
      Net::HTTP.stub(:start, ->(*, **) { raise SocketError, "getaddrinfo: nodename nor servname provided" }) do
        output = capture_log do
          assert_raises(PageFetcher::FetchFailed) do
            PageFetcher.fetch!("https://example.com/page", allowed_hosts: ALLOWED)
          end
        end

        assert_match(/\[PageFetcher\] SocketError/, output)
      end
    end
  end

  private

  def capture_log
    io = StringIO.new
    original = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = original
  end

  def with_http_status(response)
    fake_start = lambda do |*_args, **_kwargs, &block|
      http = Object.new
      http.define_singleton_method(:request) do |_req, &response_block|
        response_block&.call(response)
        response
      end
      block ? block.call(http) : http
    end

    Net::HTTP.stub(:start, fake_start) { yield }
  end

  def with_captured_request(body)
    response = Net::HTTPSuccess.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    response.body = body
    response.define_singleton_method(:read_body) { |&block| block&.call(body); body }

    captured = nil
    fake_start = lambda do |*_args, **_kwargs, &block|
      http = Object.new
      http.define_singleton_method(:request) do |req, &response_block|
        captured = req
        response_block&.call(response)
        response
      end
      block ? block.call(http) : http
    end

    Net::HTTP.stub(:start, fake_start) { yield }
    captured
  end

  def with_resolution(map)
    Resolv.stub(:getaddresses, ->(host) { map[host] || [] }) { yield }
  end

  def with_http_response(body, requested_paths: nil, headers: {})
    response = Net::HTTPSuccess.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    headers.each { |key, value| response[key] = value }
    response.body = body
    response.define_singleton_method(:read_body) do |&block|
      block&.call(body)
      body
    end

    fake_start = lambda do |*_args, **_kwargs, &block|
      http = Object.new
      http.define_singleton_method(:request) do |req, &response_block|
        requested_paths << req.path if requested_paths
        response_block&.call(response)
        response
      end
      block ? block.call(http) : http
    end

    Net::HTTP.stub(:start, fake_start) { yield }
  end
end
