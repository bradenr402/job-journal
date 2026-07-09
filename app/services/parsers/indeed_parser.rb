module Parsers
  class IndeedParser < Base
    SOURCE_NAME = "Indeed".freeze
    ALLOWED_HOSTS = %w[
      indeed.com
      www.indeed.com
    ].freeze

    private

    def title
      text_at "h1.jobsearch-JobInfoHeader-title"
    end

    def company
      name = text_at '[data-testid="inlineHeader-companyName"]'
      return name unless name&.match?(/confidential/i)

      href = url_at '[data-testid="inlineHeader-companyName"] a'
      company_page = fetch_document(href)
      return name unless company_page

      text_at('[data-testid="cmp-HeaderLayout"] [itemprop="name"]', within: company_page) || name
    end

    def application_url
      url_at('link[rel="canonical"]') ||
        url_at("[data-indeed-apply-joburl]")
    end

    def salary
      text_at "#salaryInfoAndJobType span:first-child"
    end

    def location
      text_at '[data-testid="job-location"]'
    end

    def description
      text_at "#jobDescriptionText"
    end

    def tags
      text_list_at(
        "#benefits li, #jobDetailsSection li",
        strip: [ "style", "script", "svg title" ],
        reject: IGNORED_TAGS
      )
    end
  end
end
