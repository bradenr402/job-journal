require "test_helper"
require "minitest/mock"

class JobLeadAutofillFromUrlTest < ActiveSupport::TestCase
  # --- URL safety check -----------------------------------------------------
  test "safe_url? rejects unsupported hosts" do
    assert_not JobLeadAutofillFromUrl.safe_url?("https://example.com/jobs/123")
  end

  test "safe_url? rejects non-http schemes" do
    assert_not JobLeadAutofillFromUrl.safe_url?("javascript:alert(1)")
    assert_not JobLeadAutofillFromUrl.safe_url?("file:///etc/passwd")
  end

  test "safe_url? rejects http URLs" do
    with_resolution("www.linkedin.com" => %w[151.101.1.1]) do
      assert_not JobLeadAutofillFromUrl.safe_url?("http://www.linkedin.com/jobs/view/123/")
    end
  end

  test "safe_url? rejects malformed URLs" do
    assert_not JobLeadAutofillFromUrl.safe_url?("not a url")
    assert_not JobLeadAutofillFromUrl.safe_url?("")
    assert_not JobLeadAutofillFromUrl.safe_url?(nil)
  end

  test "safe_url? accepts a public LinkedIn https URL" do
    with_resolution("www.linkedin.com" => %w[151.101.1.1]) do
      assert JobLeadAutofillFromUrl.safe_url?("https://www.linkedin.com/jobs/view/123/")
    end
  end

  test "safe_url? rejects hosts that resolve to loopback (SSRF guard)" do
    with_resolution("www.linkedin.com" => %w[127.0.0.1]) do
      assert_not JobLeadAutofillFromUrl.safe_url?("https://www.linkedin.com/jobs/view/123/")
    end
  end

  test "safe_url? rejects hosts that resolve to private RFC1918 ranges (SSRF guard)" do
    with_resolution("www.linkedin.com" => %w[10.0.0.5]) do
      assert_not JobLeadAutofillFromUrl.safe_url?("https://www.linkedin.com/jobs/view/123/")
    end
  end

  # --- Successful parse path ------------------------------------------------
  test "call returns parsed fields for a LinkedIn page" do
    expected = JSON.parse(file_fixture("linkedin/2026-05-08-junior-developer-collabera.json").read, symbolize_names: true)

    with_resolution("www.linkedin.com" => %w[151.101.1.1]) do
      with_http_response(file_fixture("linkedin/2026-05-08-junior-developer-collabera.html").read) do
        result = JobLeadAutofillFromUrl.call("https://www.linkedin.com/jobs/view/4404473006")

        assert_predicate result, :success?
        expected.each do |key, value|
          actual = result.fields[key]
          if value.is_a?(Array)
            assert_equal value.sort, Array(actual).sort
          else
            assert_equal value, actual
          end
        end
      end
    end
  end

  test "call fetches LinkedIn collection URLs through their canonical jobs view URL" do
    requested_paths = []

    with_resolution("www.linkedin.com" => %w[151.101.1.1]) do
      with_http_response(file_fixture("linkedin/2026-05-08-junior-developer-collabera.html").read, requested_paths:) do
        JobLeadAutofillFromUrl.call("https://www.linkedin.com/jobs/collections/recommended/?currentJobId=4401981876")
      end
    end

    assert_equal [ "/jobs/view/4401981876" ], requested_paths
  end

  test "call returns failure for unsupported hosts without making a network request" do
    Net::HTTP.stub :start, ->(*) { raise "should not be called" } do
      result = JobLeadAutofillFromUrl.call("https://example.com/jobs/1")

      assert_not result.success?
      assert result.error.present?
    end
  end

  test "call names supported autofill sources for unsupported hosts" do
    Net::HTTP.stub :start, ->(*) { raise "should not be called" } do
      result = JobLeadAutofillFromUrl.call("https://example.com/jobs/1")

      assert_equal "That host is not supported yet. Try a LinkedIn or Indeed job URL.", result.error
    end
  end

  test "call reports and logs when the site blocks the request" do
    forbidden = Net::HTTPForbidden.new("1.1", "403", "Forbidden")

    with_resolution("www.indeed.com" => %w[151.101.1.1]) do
      with_http_object(forbidden) do
        output = capture_log do
          result = JobLeadAutofillFromUrl.call("https://www.indeed.com/viewjob?jk=example_job_id")

          assert_not result.success?
          assert_match(/blocking automated requests/, result.error)
        end

        assert_match %r{\[PageFetcher\] HTTP 403 Forbidden for https:\/\/www\.indeed\.com\/viewjob\?jk=example_job_id}, output
      end
    end
  end

  test "call refuses responses with oversized content length before parsing" do
    html = file_fixture("linkedin/2026-05-08-junior-developer-collabera.html").read

    with_resolution("www.linkedin.com" => %w[151.101.1.1]) do
      with_http_response(html, headers: { "content-length" => (PageFetcher::MAX_BODY_BYTES + 1).to_s }) do
        result = JobLeadAutofillFromUrl.call("https://www.linkedin.com/jobs/view/4404473006")

        assert_not result.success?
      end
    end
  end

  test "call refuses redirects to http URLs" do
    with_resolution("www.linkedin.com" => %w[151.101.1.1]) do
      with_http_redirect("http://www.linkedin.com/jobs/view/4404473006") do
        result = JobLeadAutofillFromUrl.call("https://www.linkedin.com/jobs/view/123")

        assert_not result.success?
      end
    end
  end

  test "Net::HTTP and Resolv are loaded so the service works at runtime" do
    assert defined?(Net::HTTP), "Net::HTTP must be required"
    assert defined?(Resolv), "Resolv must be required for the SSRF guard to work"
  end

  private

  # --- helpers --------------------------------------------------------------
  def capture_log
    io = StringIO.new
    original = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = original
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

    with_http_object(response, requested_paths:) { yield }
  end

  def with_http_redirect(location, requested_paths: nil)
    response = Net::HTTPFound.new("1.1", "302", "Found")
    response["location"] = location

    with_http_object(response, requested_paths:) { yield }
  end

  def with_http_object(response, requested_paths: nil)
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
