module Parsers
  class LinkedInParser < Base
    SOURCE_NAME = "LinkedIn".freeze
    ALLOWED_HOSTS = %w[
      linkedin.com
      www.linkedin.com
    ].freeze

    def self.canonical_url(uri)
      return uri unless uri.host.to_s.downcase.in?(ALLOWED_HOSTS)
      return uri unless uri.path.start_with?("/jobs/collections/")

      job_id = CGI.parse(uri.query.to_s)["currentJobId"]&.first
      return uri unless job_id&.match?(/\A\d+\z/)

      uri.dup.tap do |canonical_uri|
        canonical_uri.path = "/jobs/view/#{job_id}"
        canonical_uri.query = nil
        canonical_uri.fragment = nil
      end
    end

    private

    def title
      text_at "h1.topcard__title"
    end

    def company
      text_at "a.topcard__org-name-link"
    end

    def application_url
      url_at('link[rel="canonical"]') ||
        attr_at('meta[property="og:url"]', attr: "content")
    end

    def salary
      text_at ".salary, .compensation__salary"
    end

    def location
      text_at ".topcard__flavor--bullet"
    end

    def description
      text_at ".show-more-less-html__markup"
    end

    def contact
      return unless message_section = doc.at_css(".message-the-recruiter")

      contact_name = text_at(".base-main-card__title", within: message_section)
      return unless contact_name

      href = url_at("a.message-the-recruiter__cta", within: message_section)

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

    def tags
      return [] unless list = doc.at_css(".description__job-criteria-list")

      text_list_at(
        ".description__job-criteria-text",
        within: list,
        reject: IGNORED_TAGS
      )
    end
  end
end
