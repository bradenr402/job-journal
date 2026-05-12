require "net/http"
require "resolv"

class JobLeadAutofillFromUrl
  Result = Data.define(:success?, :fields, :error) do
    def to_h_for_json = { success: success?, fields: fields, error: error }
  end

  ALLOWED_HOSTS = %w[
    linkedin.com
    www.linkedin.com
  ].freeze

  REQUEST_TIMEOUT = 8 # seconds, applied to both open and read
  MAX_REDIRECTS   = 3
  MAX_BODY_BYTES  = 2_000_000
  USER_AGENT      = "JobJournalBot/1.0 (+https://job-journal.fly.dev)"

  def self.call(url) = new(url).call
  def self.safe_url?(url) = new(url).send(:safe?)

  def initialize(url)
    @url = url
  end

  def call
    uri = parse_uri @url
    return failure "Please provide a valid http(s) URL." unless uri
    return failure "That host is not supported yet. Try a LinkedIn job URL." unless allowed_host? uri
    return failure "Refusing to fetch from a private network." unless public_host? uri

    html = fetch_html uri
    return failure "Could not fetch that page. Double-check the URL and try again." unless html

    success parse(uri, html)
  rescue StandardError => e
    Rails.logger.warn "[JobLeadAutofillFromUrl] #{e.class}: #{e.message}"
    failure "Something went wrong while reading that page."
  end

  private

  attr_reader :url

  def safe?
    uri = parse_uri url
    uri && allowed_host?(uri) && public_host?(uri)
  end

  def parse_uri(raw)
    uri = URI.parse raw.to_s.strip
    return unless uri.is_a?(URI::HTTP)
    return if uri.host.blank?

    uri
  rescue URI::InvalidURIError
    nil
  end

  def allowed_host?(uri)
    ALLOWED_HOSTS.include? uri.host.to_s.downcase
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

  def fetch_html(uri, redirects_left: MAX_REDIRECTS)
    response = Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: uri.scheme == "https",
      open_timeout: REQUEST_TIMEOUT,
      read_timeout: REQUEST_TIMEOUT
    ) do |http|
      request = Net::HTTP::Get.new(uri.request_uri, "User-Agent" => USER_AGENT, "Accept" => "text/html")
      http.request request
    end

    case response
    when Net::HTTPSuccess
      response.body.to_s.byteslice(0, MAX_BODY_BYTES)
    when Net::HTTPRedirection
      follow_redirect uri, response["location"], redirects_left
    end
  end

  def follow_redirect(uri, location, redirects_left)
    return if redirects_left.zero?

    next_uri = URI.parse location
    next_uri = uri + next_uri unless next_uri.absolute?
    return unless allowed_host?(next_uri) && public_host?(next_uri)

    fetch_html next_uri, redirects_left: redirects_left - 1
  end

  def parse(uri, html)
    document = Nokolexbor::HTML(html)
    parser_for(uri).new(document).to_h
  end

  def parser_for(uri)
    case uri.host.downcase
    when "linkedin.com", "www.linkedin.com" then LinkedInJobParser
    end
  end

  def success(fields) = Result.new(success?: true, fields: fields.compact_blank, error: nil)
  def failure(message) = Result.new(success?: false, fields: {}, error: message)
end
