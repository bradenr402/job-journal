module Parsers
  class Base
    ALLOWED_HOSTS = [].freeze

    IGNORED_TAGS = [
      /\Anot applicable\z/i,
      /\Anot specified\z/i,
      /\$/
    ].freeze

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
      (?:
       (?:compensation|salary|pay|rate)\s*[:\-]?\s*
      )?
      (?<amount>
       \$\s*[\d]{1,3}(?:,\d{3})*(?:\.\d{2})?
         (?:\s*(?:to|-|–)\s*\$?\s*[\d]{1,3}(?:,\d{3})*(?:\.\d{2})?)?
         \+?
      )
    (?<unit>
     \s*(?:per\s+(?:hour|hr|year|yr|month|mo|week|wk|annum)
         |\/\s*(?:hour|hr|year|yr|month|mo|week|wk)
         |annually|hourly|monthly|weekly
        )?
    )?
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
        source: self.class::SOURCE_NAME,
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

    def title; end
    def company; end
    def application_url; end
    def salary; end
    def contact; end
    def location; end
    def description; end
    def tags = []

    def normalize(hash)
      NORMALIZERS.reduce(hash) { |acc, fn| send(fn, acc) }
      hash.deep_compact_blank!
    end

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

      derived_tags = self.class::TITLE_TAG_RULES.map do |regex, tag|
        tag if title.match?(regex)
      end

      hash[:tags].concat derived_tags
      hash
    end

    def add_description_tags(hash)
      body = description
      return hash unless hash[:tags].present? && body.present?

      derived_tags = self.class::DESCRIPTION_TAG_RULES.map do |regex, tag|
        tag if body.match?(regex)
      end

      hash[:tags].concat derived_tags
      hash
    end

    def backfill_salary_from_description(hash)
      return hash if hash[:salary].present?

      body = description
      return hash unless body.present? && match = body.match(self.class::SALARY_PATTERN)

      hash[:salary] = "#{match[:amount]}#{match[:unit]}".squish
      hash
    end

    def text_at(selector, within: doc, strip: %w[style script])
      return unless node = within.at_css(selector)

      node.css(strip.join(",")).remove if strip.present?

      node.text.to_s.squish.presence
    end

    def text_list_at(selector, within: doc, strip: %w[style script], reject: [])
      nodes = within.css selector
      return [] if nodes.empty?

      nodes.filter_map do |node|
        node.css(strip.join(",")).remove if strip.present?

        value = node.text.to_s.squish.presence
        next if value && reject.any? { it.match? value }

        value
      end.uniq
    end

    def attr_at(selector, within: doc, attr: nil)
      return unless attr.present? && node = within.at_css(selector)

      node.attr(attr).to_s.squish.presence
    end

    def url_at(selector, within: doc) = attr_at(selector, within:, attr: "href")

    def fetch_document(url, allowed_hosts: self.class::ALLOWED_HOSTS)
      html = PageFetcher.fetch(url, allowed_hosts:)
      Nokolexbor::HTML(html) if html
    end
  end
end
