require "net/http"
require "resolv"
require "timeout"

class JobLeadAutofillFromUrl
  Result = Data.define(:success?, :fields, :error) do
    def to_h_for_json = { success: success?, fields: fields, error: error }
  end

  def self.call(url) = new(url).call
  def self.safe_url?(url) = new(url).safe?

  def initialize(url)
    @url = url
  end

  def call
    html = fetcher.fetch!
    success parse(target_uri, html)
  rescue PageFetcher::Error => e
    failure error_message_for(e)
  end

  def safe?
    fetcher.safe?
  end

  private

  attr_reader :url

  def fetcher
    PageFetcher.new(url, allowed_hosts: Parsers.hosts, canonicalize: method(:canonical_uri))
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
    Parsers.for_host(uri.host)
  end

  def success(fields) = Result.new(success?: true, fields: fields.compact_blank, error: nil)
  def failure(message) = Result.new(success?: false, fields: {}, error: message)

  def error_message_for(error)
    case error
    when PageFetcher::InvalidUrl
      "Please provide a valid https URL."
    when PageFetcher::UnsupportedHost
      "That host is not supported yet. Try a #{Parsers.source_names.to_disjunctive_sentence} job URL."
    when PageFetcher::PrivateHost
      "Refusing to fetch from a private network."
    when PageFetcher::BodyTooLarge
      "That page is too large to autofill."
    when PageFetcher::AccessBlocked
      "That site is blocking automated requests right now. Try again later, or enter the details manually."
    else
      "Could not fetch that page. Double-check the URL and try again."
    end
  end
end
