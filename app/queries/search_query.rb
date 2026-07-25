class SearchQuery
  SCOPES = %w[ all job_leads interviews notes ].freeze
  EMPTY_RESULTS = { job_leads: [], interviews: [], notes: [] }.freeze

  # Matches double-quoted phrases, single-quoted phrases, or bare words.
  TERM_PATTERN = /"([^"]+)"|'([^']+)'|(\S+)/

  # `scope` narrows the search to a single resource type ("all" searches
  # everything). `filters` maps resource keys (:job_leads, :interviews,
  # :notes) to ApplicationFilters instances applied to each result set.
  def initialize(user, query, scope: "all", filters: {})
    @user = user
    @query = query.to_s.strip
    @scope = scope.to_s.presence_in(SCOPES) || "all"
    @filters = filters
  end

  # Returns a hash of search results for job_leads, interviews, and notes.
  def results
    return EMPTY_RESULTS if @query.blank?

    case @scope
    when "job_leads"
      single_result(:job_leads, search_job_leads.limit(30))
    when "interviews"
      single_result(:interviews, search_interviews.limit(30))
    when "notes"
      single_result(:notes, search_notes.limit(30))
    else
      all_results
    end
  end

  private

  def single_result(key, value) = EMPTY_RESULTS.merge(key => value)

  def all_results
    {
      job_leads: search_job_leads.limit(10),
      interviews: search_interviews.limit(10),
      notes: search_notes.limit(10)
    }
  end

  def filtered(key, scope)
    @filters[key]&.apply(scope) || scope
  end

  def terms
    @terms ||= @query.scan(TERM_PATTERN).map { it.compact.first.downcase }
  end

  def search_job_leads
    scope = filtered(:job_leads, @user.job_leads.includes(:tags))

    terms.reduce(scope) do |current_scope, term|
      current_scope.where(job_lead_conditions, term: "%#{term}%")
    end
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

    terms.reduce(scope) do |current_scope, term|
      current_scope.where(interview_conditions, term: "%#{term}%")
    end
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

    terms.reduce(scope) do |current_scope, term|
      current_scope.where("LOWER(content) LIKE ?", "%#{term}%")
    end
  end
end
