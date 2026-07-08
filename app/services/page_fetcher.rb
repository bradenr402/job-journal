require "net/http"
require "resolv"
require "timeout"

class PageFetcher
  REQUEST_TIMEOUT = 8 # seconds, applied to both open and read
  MAX_REDIRECTS   = 3
  MAX_BODY_BYTES  = 2_000_000
  USER_AGENT      = "JobJournalBot/1.0 (+https://job-journal.fly.dev)"

  Error           = Class.new(StandardError)
  InvalidUrl      = Class.new(Error)
  UnsupportedHost = Class.new(Error)
  PrivateHost     = Class.new(Error)
  BodyTooLarge    = Class.new(Error)
  FetchFailed     = Class.new(Error)

  def self.fetch(...) = new(...).fetch
  def self.fetch!(...) = new(...).fetch!
  def self.safe?(...) = new(...).safe?

  def initialize(url, allowed_hosts:, canonicalize: nil)
    @url = url
    @allowed_hosts = allowed_hosts
    @canonicalize = canonicalize
  end

  def fetch
    fetch!
  rescue Error
    nil
  end

  def fetch!
    uri = safe_uri!

    html =
      begin
        Timeout.timeout(REQUEST_TIMEOUT) { request_html uri }
      rescue BodyTooLarge
        raise
      rescue Timeout::Error
        raise FetchFailed
      rescue StandardError => e
        Rails.logger.warn "[PageFetcher] #{e.class}: #{e.message}"
        raise FetchFailed
      end

    raise FetchFailed if html.nil?

    html
  end

  def safe?
    safe_uri!
    true
  rescue Error
    false
  end
  private

  attr_reader :url, :allowed_hosts, :canonicalize

  def safe_uri!
    uri = parse_uri(url) or raise InvalidUrl
    uri = canonicalize_uri uri
    raise UnsupportedHost unless allowed_host? uri
    raise PrivateHost unless public_host? uri

    uri
  end

  def parse_uri(raw)
    uri = URI.parse raw.to_s.strip
    return unless uri.is_a?(URI::HTTP)
    return unless uri.scheme == "https"
    return if uri.host.blank?

    uri
  rescue URI::InvalidURIError
    nil
  end

  def canonicalize_uri(uri)
    return uri unless canonicalize

    canonicalize.call uri
  end

  def allowed_host?(uri)
    allowed_hosts.include? uri.host.to_s.downcase
  end

  def public_host?(uri)
    addresses = Resolv.getaddresses uri.host
    return false if addresses.empty?

    addresses.none? do |addr|
      ip = IPAddr.new addr
      ip.loopback? || ip.private? || ip.link_local?
    end
  rescue IPAddr::InvalidAddressError, Resolv::ResolvError
    false
  end

  def request_html(uri, redirects_left: MAX_REDIRECTS)
    html = nil

    Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: true,
      open_timeout: REQUEST_TIMEOUT,
      read_timeout: REQUEST_TIMEOUT
    ) do |http|
      request = Net::HTTP::Get.new(uri.request_uri, "User-Agent" => USER_AGENT, "Accept" => "text/html")
      http.request request do |response|
        html =
          case response
          when Net::HTTPSuccess
            read_limited_body response
          when Net::HTTPRedirection
            follow_redirect uri, response["location"], redirects_left
          end
      end
    end

    html
  end

  def read_limited_body(response)
    content_length = response["content-length"].to_i if response["content-length"].present?
    raise BodyTooLarge if content_length && content_length > MAX_BODY_BYTES

    body = +""
    response.read_body do |chunk|
      body << chunk
      raise BodyTooLarge if body.bytesize > MAX_BODY_BYTES
    end
    body
  end

  def follow_redirect(uri, location, redirects_left)
    return if redirects_left.zero?

    next_uri = URI.parse location
    next_uri = uri + next_uri unless next_uri.absolute?
    next_uri = canonicalize_uri next_uri
    return unless next_uri.scheme == "https"
    return unless allowed_host?(next_uri) && public_host?(next_uri)

    request_html next_uri, redirects_left: redirects_left - 1
  end
end
