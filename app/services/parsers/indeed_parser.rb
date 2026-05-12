module Parsers
  class IndeedParser < Base
    SOURCE_NAME = "Indeed".freeze
    ALLOWED_HOSTS = %w[
      linkedin.com
      www.linkedin.com
    ].freeze

    private

    def title
      text_at "h1.jobsearch-JobInfoHeader-title"
    end

    def company
      text_at '[data-testid="inlineHeader-companyName"]', strip: %w[style]
    end

    def application_url
      attr_at("[data-indeed-apply-joburl]", attr: "data-indeed-apply-joburl")
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
        reject: IGNORED_TAGS
      )
    end
  end
end
