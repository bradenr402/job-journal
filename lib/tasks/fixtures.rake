require "net/http"
require "active_support/number_helper"

namespace :fixtures do
  PARSER_SUBDIRS = {
    "linkedin.com"     => "linkedin",
    "www.linkedin.com" => "linkedin",
    "indeed.com"       => "indeed",
    "www.indeed.com"   => "indeed"
  }.freeze

  desc "Download a job page and create matching .html / .json fixtures (args: NAME, URL; FORCE=1 to overwrite)"
  task :job, [ :name, :url ] => :environment do |_, args|
    name  = args[:name].presence || ENV["NAME"].presence
    url   = args[:url].presence  || ENV["URL"].presence
    force = ActiveModel::Type::Boolean.new.cast(ENV["FORCE"])

    print_banner

    unless name && url
      print_error "Missing required arguments."
      print_hint "bin/rails 'fixtures:job[name,url]'  (or NAME=… URL=… bin/rails fixtures:job)"
      print_hint "Pass FORCE=1 to overwrite existing files."
      exit 1
    end

    subdir = parser_subdir_for(url)
    unless subdir
      print_error "No parser configured for that host."
      print_hint "Supported hosts: #{PARSER_SUBDIRS.keys.join(', ')}"
      exit 1
    end

    fixtures_dir = Rails.root.join("test/fixtures/files", subdir)
    html_path    = fixtures_dir.join("#{name}.html")
    json_path    = fixtures_dir.join("#{name}.json")

    unless force
      [ html_path, json_path ].each do |path|
        next unless path.exist?
        print_error "#{path.relative_path_from(Rails.root)} already exists"
        print_hint "Pass FORCE=1 to overwrite."
        exit 1
      end
    end

    fixtures_dir.mkpath

    print_step "Fetching #{dim(url)}"
    html = fetch_html(url)

    if html.blank?
      print_error "No content received."
      exit 1
    end

    print_status html_path, replaced: html_path.exist?, suffix: human_size(html.bytesize)
    html_path.binwrite(html)

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

  def parser_subdir_for(url)
    uri = URI.parse(url.to_s)
    PARSER_SUBDIRS[uri.host&.downcase]
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
  # Fetching

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
end
