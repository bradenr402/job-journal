require "net/http"
require "active_support/number_helper"

namespace :fixtures do
  desc "Create matching .html / .json fixtures from a job URL or a saved .html file (args: NAME, SOURCE; FORCE=1 to overwrite)"
  task :job, [ :name, :source ] => :environment do |_, args|
    name   = args[:name].presence   || ENV["NAME"].presence
    source = args[:source].presence || ENV["SOURCE"].presence
    force  = ActiveModel::Type::Boolean.new.cast(ENV["FORCE"])

    print_banner

    unless name && source
      print_error "Missing required arguments."
      print_hint "bin/rails 'fixtures:job[name,source]'  (or NAME=… SOURCE=… bin/rails fixtures:job)"
      print_hint "SOURCE is a job URL to fetch, or a path to an .html page saved from your browser."
      print_hint "Pass FORCE=1 to overwrite existing files."
      exit 1
    end

    html, url = resolve_source(source)

    parser = parser_for_url(url)
    unless parser
      print_error "No parser configured for that host."
      print_hint "Supported hosts: #{Parsers.hosts.join(', ')}"
      exit 1
    end

    subdir       = parser::SOURCE_NAME.downcase
    slug         = "#{Date.current.iso8601}-#{name.tr('_', '-')}"
    fixtures_dir = Rails.root.join("test/fixtures/files", subdir)
    html_path    = fixtures_dir.join("#{slug}.html")
    json_path    = fixtures_dir.join("#{slug}.json")

    unless force
      [ html_path, json_path ].each do |path|
        next unless path.exist?
        print_error "#{path.relative_path_from(Rails.root)} already exists"
        print_hint "Pass FORCE=1 to overwrite."
        exit 1
      end
    end

    fixtures_dir.mkpath

    html ||= fetch_primary_html(url)

    print_status html_path, replaced: html_path.exist?, suffix: human_size(html.bytesize)
    html_path.binwrite(html)

    download_secondary_pages(url, html, slug:, dir: fixtures_dir)

    print_status json_path, replaced: json_path.exist?, suffix: "stub — fill in expected fields"
    json_path.write("{}\n")

    puts
    puts bold(green("Done!")) + " Edit the JSON to add the expected parser output."
    puts
  end

  # ---------------------------------------------------------------------------
  # Output helpers

  def print_banner
    puts
    puts bold("  Job Fixture Generator")
    puts dim("  ─────────────────────")
    puts
  end

  def print_step(message)
    puts "  #{cyan('▸')} #{message}"
  end

  def print_status(path, replaced:, suffix:)
    relative = path.relative_path_from(Rails.root)
    if replaced
      puts "  #{yellow('⚠')} #{yellow('Overwrote')} #{bold(relative.to_s)} #{dim("(#{suffix})")}"
    else
      puts "  #{green('✓')} #{green('Wrote')} #{bold(relative.to_s)} #{dim("(#{suffix})")}"
    end
  end

  def print_error(message)
    warn "  #{red('✗')} #{red(message)}"
  end

  def print_hint(message)
    warn "    #{dim(message)}"
  end

  def human_size(bytes)
    ActiveSupport::NumberHelper.number_to_human_size(bytes)
  end

  def parser_for_url(url)
    uri = URI.parse(url.to_s)
    Parsers.for_host(uri.host)
  rescue URI::InvalidURIError
    nil
  end

  # ---------------------------------------------------------------------------
  # ANSI styling

  def bold(message)   = colorize(1, message)
  def dim(message)    = colorize(2, message)
  def red(message)    = colorize(31, message)
  def green(message)  = colorize(32, message)
  def yellow(message) = colorize(33, message)
  def cyan(message)   = colorize(36, message)

  def colorize(code, message)
    $stdout.tty? ? "\e[#{code}m#{message}\e[0m" : message.to_s
  end

  # ---------------------------------------------------------------------------
  # Source resolution

  # A source is either a URL to fetch or a path to a saved HTML page.
  def resolve_source(source)
    return [ nil, source ] if url_source?(source)

    print_step "Reading #{dim(source)}"
    html = read_html_file(source)
    url  = canonical_url(html)

    unless url
      print_error "Couldn't determine the source URL from that file."
      print_hint "The saved page has no <link rel=\"canonical\"> — pass the job URL instead."
      exit 1
    end

    [ html, url ]
  end

  def url_source?(source)
    source.to_s.match?(%r{\Ahttps?://}i)
  end

  def read_html_file(path)
    file = Pathname.new(path).expand_path
    return file.read if file.exist?

    print_error "No such file: #{path}"
    exit 1
  end

  def canonical_url(html)
    doc = Nokolexbor::HTML(html)
    doc.at_css('link[rel="canonical"]')&.attr("href").presence ||
      doc.at_css('meta[property="og:url"]')&.attr("content").presence
  end

  # ---------------------------------------------------------------------------
  # Fetching

  def fetch_primary_html(url)
    print_step "Fetching #{dim(url)}"
    html = fetch_html(url)
    return html if html.present?

    print_error "No content received."
    exit 1
  rescue => e
    print_error "Could not fetch the page: #{e.message}"
    print_hint "If the site blocks automated requests (e.g. a Cloudflare check), save the"
    print_hint "page from your browser and pass its file path as the source instead."
    exit 1
  end

  def fetch_html(url, redirects_remaining: 5)
    raise "Too many redirects" if redirects_remaining.negative?

    uri = URI.parse(url)
    raise "Only http(s) URLs are supported" unless uri.is_a?(URI::HTTP)

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"
    request["Accept"] = "text/html,application/xhtml+xml"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.open_timeout = 10
      http.read_timeout = 30
      http.request(request)
    end

    case response
    when Net::HTTPRedirection
      fetch_html(URI.join(url, response["location"]).to_s, redirects_remaining: redirects_remaining - 1)
    when Net::HTTPSuccess
      response.body
    else
      raise "HTTP #{response.code} #{response.message}"
    end
  end

  # ---------------------------------------------------------------------------
  # Secondary pages

  # Runs the parser against the primary page and downloads any secondary pages
  # it fetches via fetch_document. Each page is named after the method that
  # fetched it (e.g. a fetch inside #company -> "#{slug}_company.html"), so the
  # generated name always matches what the test helper looks for.
  def download_secondary_pages(primary_url, primary_html, slug:, dir:)
    parser_class = parser_for_url(primary_url)
    return unless parser_class

    fetch   = method(:fetch_html)
    step    = method(:print_step)
    dimmed  = method(:dim)
    parser  = parser_class.new(Nokolexbor::HTML(primary_html))
    fetched = []
    missing = []

    parser.define_singleton_method(:fetch_document) do |page_url, **|
      next if page_url.blank?

      name = caller_locations(1, 1).first.base_label
      path = dir.join("#{slug}_#{name.dasherize}.html")

      next Nokolexbor::HTML(path.read) if path.exist?

      step.call("Fetching #{name.humanize.downcase} page #{dimmed.call(page_url)}")

      page_html =
        begin
          fetch.call(page_url)
        rescue => e
          missing << [ path, page_url, e.message ]
          next
        end
      next if page_html.blank?

      fetched << [ path, page_html ]
      Nokolexbor::HTML(page_html)
    end

    parser.to_h

    fetched.each do |path, page_html|
      print_status path, replaced: path.exist?, suffix: human_size(page_html.bytesize)
      path.binwrite(page_html)
    end

    missing.each { |path, page_url, reason| print_missing_page(path, page_url, reason) }
  end

  def print_missing_page(path, page_url, reason)
    warn "  #{yellow('⚠')} #{yellow('Could not fetch a secondary page')} #{dim("(#{reason})")}"
    print_hint "Open #{page_url}"
    print_hint "then save it as #{path.relative_path_from(Rails.root)} and re-run."
  end
end
