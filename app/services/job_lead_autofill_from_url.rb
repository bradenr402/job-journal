require "net/http"
require "resolv"
require "timeout"

class JobLeadAutofillFromUrl
  Result = Data.define(:success?, :fields, :error) do
    def to_h_for_json = { success: success?, fields: fields, error: error }
  end

  ALLOWED_HOSTS = %w[
    linkedin.com
    www.linkedin.com
    indeed.com
    www.indeed.com
  ].freeze

  def self.call(url) = new(url).call
  def self.safe_url?(url) = new(url).safe?

  def initialize(url)
    @url = url
  end

  def call
    html = fetcher.fetch!
    success parse(target_uri, html)
  rescue PageFetcher::InvalidUrl
    failure "Please provide a valid https URL."
  rescue PageFetcher::UnsupportedHost
    failure "That host is not supported yet. Try a #{::Constants::SUPPORTED_AUTOFILL_SOURCES.to_disjunctive_sentence} job URL."
  rescue PageFetcher::PrivateHost
    failure "Refusing to fetch from a private network."
  rescue PageFetcher::BodyTooLarge
    failure "That page is too large to autofill."
  rescue PageFetcher::Error
    failure "Could not fetch that page. Double-check the URL and try again."
  end

  def safe?
    fetcher.safe?
  end

  private

  attr_reader :url

  def fetcher
    PageFetcher.new(url, allowed_hosts: ALLOWED_HOSTS, canonicalize: method(:canonical_uri))
  end

  def target_uri
    uri = parse_uri url
    uri && canonical_uri(uri)
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

  def canonical_uri(uri)
    parser = parser_for uri
    return uri unless parser.respond_to? :canonical_url

    parser.canonical_url uri
  end

  def parse(uri, html)
    document = Nokolexbor::HTML(html)
    parser_for(uri).new(document).to_h
  end

  def parser_for(uri)
    case uri.host.downcase
    when "linkedin.com", "www.linkedin.com" then Parsers::LinkedInParser
    when "indeed.com", "www.indeed.com" then Parsers::IndeedParser
    end
  end

  def success(fields) = Result.new(success?: true, fields: fields.compact_blank, error: nil)
  def failure(message) = Result.new(success?: false, fields: {}, error: message)
end
