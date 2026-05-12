class LinkedInJobParser
  SOURCE_NAME = "LinkedIn".freeze
  ALLOWED_HOSTS = %w[
    linkedin.com
    www.linkedin.com
  ].freeze
  IGNORED_TAGS = [ "not applicable", "not specified" ].freeze
  TITLE_TAG_RULES = {
    /\bintern(ship)?\b/i => "intern",
    /\b(entry[- ]?level|new grad|recent graduate)\b/i => "entry-level",
    /\b(junior|jr\.?)\b/i => "junior",
    /\b(mid[- ]?level|intermediate)\b/i => "mid-level",
    /\b(senior|sr\.?)\b/i => "senior",
    /\bstaff\b/i => "staff",
    /\blead\b/i => "lead",
    /\bprincipal\b/i => "principal",
    /\b(manager|mgr)\b/i => "manager",
    /\bdirector\b/i => "director"
  }.freeze
  DESCRIPTION_TAG_RULES = {
    /\bjavascript\b|\bjs\b/i => "javascript",
    /\btypescript\b|\bts\b/i => "typescript",
    /\bpython\b/i => "python",
    /\bruby\b/i => "ruby",
    /\brails\b/i => "rails",
    /\bjava\b/i => "java",
    /\bgo(?:lang)?\b/i => "go",
    /\brust\b/i => "rust",
    /\bc\+\+\b/i => "c++",
    /\bc#\b/i => "c#",
    /\breact\b/i => "react",
    /\bvue\b/i => "vue",
    /\bangular\b/i => "angular",
    /\bnode\.?js\b/i => "node.js",
    /\bsql\b/i => "sql",
    /\bgit(?:hub)?\b/i => "github",
    /\bdocker\b/i => "docker",
    /\bkubernetes\b|\bk8s\b/i => "kubernetes",
    /\baws\b/i => "aws",
    /\bazure\b/i => "azure",
    /\b(artificial intelligence|ai)\b/i => "ai",
    /\b(machine learning|ml)\b/i => "machine learning",
    /full[- ]?stack/i => "full-stack",
    /front[- ]?end/i => "front-end",
    /back[- ]?end/i => "back-end",
    /\bapis?\b|\brest(?:ful)?\b/i => "api",
    /\bremote\b/i => "remote",
    /\bhybrid\b/i => "hybrid",
    /on[- ]?site/i => "on-site",
    /\bmedical insurance\b|\bhealth insurance\b/i => "health insurance",
    /\bdental(?: insurance)?\b/i => "dental insurance",
    /\bvision(?: insurance)?\b/i => "vision insurance",
    /\b401\(?k\)?\b/i => "401(k)",
    /\blife insurance\b/i => "life insurance",
    /\bcommuter benefits\b|paid (?:parking|public transportation|transit)/i => "commuter benefits",
    /\bpaid time off\b|\bpto\b/i => "paid time off",
    /\bpaid sick\b|\bsick leave\b/i => "paid sick leave",
    /\bpaid vacation\b|\bvacation time\b/i => "paid vacation",
    /\bparental leave\b|\bmaternity leave\b|\bpaternity leave\b/i => "parental leave",
    /\bpaid holidays?\b/i => "paid holidays"
  }.freeze
  SALARY_PATTERN = /
    (?:compensation|salary|pay|rate)\s*[:\-]?\s*
    (?<amount>\$[\d,]+(?:\.\d+)?(?:\s*[-–to]+\s*\$?[\d,]+(?:\.\d+)?)?)
    (?<unit>\s*(?:per\s+(?:hour|hr|year|yr|month|mo|week|wk|annum)|\/\s*(?:hour|hr|year|yr|month|mo|week|wk)|annually|hourly|monthly|weekly))?
  /ix
  NORMALIZERS = [
    :add_title_tags,
    :add_description_tags,
    :backfill_salary_from_description,
    :normalize_tags
  ].freeze

  def initialize(document)
    @doc = document
  end

  def to_h
    normalize({
      source: SOURCE_NAME,
      title: title,
      company: company,
      application_url: application_url,
      salary: salary,
      contact: contact,
      location: location,
      tags: tags
    })
  end

  private

  attr_reader :doc

  def normalize(hash)
    NORMALIZERS.reduce(hash) { |acc, fn| send(fn, acc) }
    hash.deep_compact_blank!
  end

  def title
    text_at("h1.topcard__title")
  end

  def company
    text_at("a.topcard__org-name-link")
  end

  def application_url
    attr_at('link[rel="canonical"]', attr: "href") ||
      attr_at('meta[property="og:url"]', attr: "content")
  end

  def salary
    text_at(".salary, .compensation__salary")
  end

  def contact
    return unless message_section = doc.at_css(".message-the-recruiter")

    contact_name = text_at(".base-main-card__title", within: message_section)
    return unless contact_name

    href = attr_at("a.message-the-recruiter__cta", within: message_section, attr: "href")

    message_link =
      if href.present?
        uri = URI.parse href
        params = CGI.parse uri.query.to_s

        link = CGI.unescape params["session_redirect"]&.first.presence
        parsed = URI.parse(link.to_s) rescue nil

        parsed.to_s if parsed.is_a?(URI::HTTP) && parsed.host&.in?(ALLOWED_HOSTS)
      end

    message_link.present? ? "#{contact_name} (#{message_link})".squish.presence : contact_name
  end

  def location
    text_at(".topcard__flavor--bullet")
  end

  def description
    text_at(".show-more-less-html__markup")
  end

  def tags
    return [] unless list = doc.at_css(".description__job-criteria-list")

    text_list_at(
      ".description__job-criteria-text",
      within: list,
      reject: IGNORED_TAGS
    )
  end

  # --- Normalization --------------------------------------------------------

  def normalize_tags(hash)
    return hash unless hash[:tags].present?

    hash[:tags]
      .compact_blank!
      .map!(&:downcase)
      .uniq!

    hash
  end

  def add_title_tags(hash)
    title = hash[:title]
    return hash unless hash[:tags].present? && title.present?

    derived_tags = TITLE_TAG_RULES.map do |regex, tag|
      tag if title.match?(regex)
    end

    hash[:tags].concat derived_tags
    hash
  end

  def add_description_tags(hash)
    body = description
    return hash unless hash[:tags].present? && body.present?

    derived_tags = DESCRIPTION_TAG_RULES.map do |regex, tag|
      tag if body.match?(regex)
    end

    hash[:tags].concat derived_tags
    hash
  end

  def backfill_salary_from_description(hash)
    return hash if hash[:salary].present?

    body = description
    return hash unless body.present? && match = body.match(SALARY_PATTERN)

    hash[:salary] = "#{match[:amount]}#{match[:unit]}".squish
    hash
  end

  # --- Helpers --------------------------------------------------------------

  def text_at(selector, within: doc)
    return unless node = within.at_css(selector)

    node.text.to_s.squish.presence
  end

  def text_list_at(selector, within: doc, reject: [])
    nodes = within.css selector
    return [] if nodes.empty?

    nodes.filter_map do |node|
      value = node.text.to_s.squish.presence
      next if value&.downcase&.in?(reject)

      value
    end.uniq
  end

  def attr_at(selector, within: doc, attr: nil)
    return unless attr.present? && node = within.at_css(selector)

    node.attr(attr).to_s.squish.presence
  end
end
