class SearchQuery
  RESULT_KEYS = %i[ job_leads interviews notes ].freeze
  SCOPES = [ "all", *RESULT_KEYS.map(&:to_s) ].freeze
  EMPTY_RESULTS = RESULT_KEYS.index_with { [].freeze }.freeze

  COMBINED_LIMIT = 10
  SCOPED_LIMIT = COMBINED_LIMIT * RESULT_KEYS.size

  # Matches double-quoted phrases, single-quoted phrases, or bare words.
  TERM_PATTERN = /"([^"]+)"|'([^']+)'|(\S+)/

  attr_reader :scope

  def self.resolve_scope(scope) = scope.to_s.presence_in(SCOPES) || "all"

  # `scope` narrows the search to a single resource type ("all" searches
  # everything). `filters` maps resource keys (:job_leads, :interviews,
  # :notes) to ApplicationFilters instances applied to each result set.
  def initialize(user, query, scope: "all", filters: {})
    @user = user
    @query = query.to_s.strip
    @scope = self.class.resolve_scope(scope)
    @filters = filters
  end

  # Returns a hash of search results for job_leads, interviews, and notes.
  def results
    return EMPTY_RESULTS if @query.blank?

    EMPTY_RESULTS.merge(result_keys.index_with { limited_search it })
  end

  private

  def result_keys = scope == "all" ? RESULT_KEYS : [ scope.to_sym ]

  def result_limit = scope == "all" ? COMBINED_LIMIT : SCOPED_LIMIT

  def limited_search(key)
    case key
    when :job_leads then search_job_leads
    when :interviews then search_interviews
    when :notes then search_notes
    else raise ArgumentError, "Unknown result key: #{key.inspect}"
    end.limit(result_limit)
  end

  def filtered(key, scope)
    @filters[key]&.apply(scope) || scope
  end

  def terms
    @terms ||= @query.scan(TERM_PATTERN).map { it.compact.first.downcase }
  end

  def search_job_leads
    scope = filtered(:job_leads, @user.job_leads.includes(:tags))
    where_terms(scope, job_lead_conditions)
  end

  def job_lead_conditions
    <<~SQL.squish
      LOWER(title) LIKE :term
      OR LOWER(company) LIKE :term
      OR LOWER(application_url) LIKE :term
      OR LOWER(source) LIKE :term
      OR LOWER(salary) LIKE :term
      OR LOWER(contact) LIKE :term
      OR CAST(offer_amount AS TEXT) LIKE :term
      OR LOWER(job_leads.location) LIKE :term
      OR EXISTS (
        SELECT 1 FROM taggings
        JOIN tags ON tags.id = taggings.tag_id
        WHERE taggings.job_lead_id = job_leads.id
          AND LOWER(tags.name) LIKE :term
      )
    SQL
  end

  def search_interviews
    scope = filtered(:interviews, @user.interviews.includes(:job_lead).order(scheduled_at: :desc))
    where_terms(scope, interview_conditions)
  end

  def interview_conditions
    <<~SQL.squish
      LOWER(interviewer) LIKE :term
      OR CAST(scheduled_at AS TEXT) LIKE :term
      OR LOWER(interviews.location) LIKE :term
      OR CAST(rating AS TEXT) LIKE :term
      OR LOWER(call_url) LIKE :term
      OR LOWER(job_leads.title) LIKE :term
      OR LOWER(job_leads.company) LIKE :term
      OR LOWER(job_leads.location) LIKE :term
      OR LOWER(job_leads.source) LIKE :term
      OR LOWER(job_leads.contact) LIKE :term
      OR CAST(job_leads.salary AS TEXT) LIKE :term
      OR CAST(job_leads.offer_amount AS TEXT) LIKE :term
    SQL
  end

  def search_notes
    scope = filtered(:notes, @user.notes)

    where_terms(scope, "LOWER(content) LIKE :term")
  end

  def where_terms(scope, conditions)
    terms.reduce(scope) do |current_scope, term|
      current_scope.where(conditions, term: "%#{term}%")
    end
  end
end
