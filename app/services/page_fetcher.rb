require "net/http"
require "resolv"
require "timeout"

class PageFetcher
  REQUEST_TIMEOUT = 8 # seconds, applied to both open and read
  MAX_REDIRECTS   = 3
  MAX_BODY_BYTES  = 2_000_000

  CHROME_VERSION = "146"

  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/#{CHROME_VERSION}.0.0.0 Safari/537.36"

  DEFAULT_HEADERS = {
    "User-Agent"                => USER_AGENT,
    "Accept"                    => "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,application/signed-exchange;v=b3;q=0.7",
    "Accept-Language"           => "en-US,en;q=0.9",
    "Referer"                   => "https://www.google.com/",
    "Sec-Ch-Ua"                 => %("Chromium";v="#{CHROME_VERSION}", "Google Chrome";v="#{CHROME_VERSION}", "Not.A/Brand";v="24"),
    "Sec-Ch-Ua-Mobile"          => "?0",
    "Sec-Ch-Ua-Platform"        => %("macOS"),
    "Upgrade-Insecure-Requests" => "1",
    "Sec-Fetch-Dest"            => "document",
    "Sec-Fetch-Mode"            => "navigate",
    "Sec-Fetch-Site"            => "cross-site",
    "Sec-Fetch-User"            => "?1"
  }.freeze

  BLOCKING_STATUSES = [ 401, 403, 429 ].freeze

  Error           = Class.new(StandardError)
  InvalidUrl      = Class.new(Error)
  UnsupportedHost = Class.new(Error)
  PrivateHost     = Class.new(Error)
  BodyTooLarge    = Class.new(Error)
  FetchFailed     = Class.new(Error)
  AccessBlocked   = Class.new(FetchFailed)

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

    html = Timeout.timeout(REQUEST_TIMEOUT) { request_html uri }
    raise FetchFailed, "Empty response body for #{uri}" if html.nil?

    html
  rescue InvalidUrl, UnsupportedHost, PrivateHost, BodyTooLarge
    raise
  rescue FetchFailed => e
    log_warn e.message
    raise
  rescue Timeout::Error
    message = "Timed out after #{REQUEST_TIMEOUT}s while fetching #{url}"
    log_warn message
    raise FetchFailed, message
  rescue StandardError => e
    message = "#{e.class}: #{e.message} while fetching #{url}"
    log_warn message
    raise FetchFailed, message
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
      request = Net::HTTP::Get.new(uri.request_uri, DEFAULT_HEADERS)
      http.request request do |response|
        html =
          case response
          when Net::HTTPSuccess
            read_limited_body response
          when Net::HTTPRedirection
            follow_redirect uri, response["location"], redirects_left
          else
            raise response_error(response, uri)
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

  def response_error(response, uri)
    message = "HTTP #{response.code} #{response.message} for #{uri}"
    klass   = BLOCKING_STATUSES.include?(response.code.to_i) ? AccessBlocked : FetchFailed

    klass.new(message)
  end

  def follow_redirect(uri, location, redirects_left)
    raise FetchFailed, "Exceeded #{MAX_REDIRECTS} redirects starting from #{uri}" if redirects_left.zero?

    next_uri = URI.parse location
    next_uri = uri + next_uri unless next_uri.absolute?
    next_uri = canonicalize_uri next_uri

    unless next_uri.scheme == "https" && allowed_host?(next_uri) && public_host?(next_uri)
      raise FetchFailed, "Refusing unsafe redirect to #{next_uri} from #{uri}"
    end

    request_html next_uri, redirects_left: redirects_left - 1
  end

  def log_warn(message)
    Rails.logger.warn "[PageFetcher] #{message}"
  end
end
