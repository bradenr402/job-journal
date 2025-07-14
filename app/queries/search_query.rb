class SearchQuery
  EMPTY_RESULTS = { job_leads: [], interviews: [], notes: [] }.freeze

  def initialize(user, query, filter: nil, status: nil, date_range: nil, notable_type: nil)
    @user = user
    @query = query.to_s.strip
    @filter = filter&.downcase
    @status = status
    @date_range = date_range
    @notable_type = notable_type
  end

  # Returns a hash of search results for job_leads, interviews, and notes.
  def results
    return EMPTY_RESULTS if @query.blank?

    case @filter
    when 'job_leads'
      single_result(:job_leads, search_job_leads.limit(30))
    when 'interviews'
      single_result(:interviews, search_interviews.limit(30))
    when 'notes'
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

  def terms
    @terms ||= @query.scan(/"([^"]+)"|'([^']+)'|(\S+)/).map { |dq, sq, unq| (dq || sq || unq).downcase }
  end

  def search_job_leads
    scope = @user.job_leads.includes(:tags)
    scope = scope.where(status: @status) if @status.present?

    terms.reduce(scope) do |current_scope, term|
      matching_statuses = matching_status_values(term)
      if matching_statuses.any?
        current_scope.where(
          "(#{job_lead_conditions}) OR status IN (:statuses)",
          term: "%#{term}%",
          statuses: matching_statuses
        )
      else
        current_scope.where(job_lead_conditions, term: "%#{term}%")
      end
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
      OR LOWER(location) LIKE :term
      OR EXISTS (
        SELECT 1 FROM taggings
        JOIN tags ON tags.id = taggings.tag_id
        WHERE taggings.job_lead_id = job_leads.id
          AND LOWER(tags.name) LIKE :term
      )
    SQL
  end

  def search_interviews
    scope = @user.interviews.includes(:job_lead).order(scheduled_at: :desc)

    scope =
      case @date_range
      when 'upcoming'
        scope.future
      when 'completed'
        scope.past
      else
        scope
      end

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
    scope = @user.notes
    scope = scope.where(notable_type: @notable_type) if @notable_type.present?

    terms.reduce(scope) do |current_scope, term|
      current_scope.where('LOWER(content) LIKE ?', "%#{term}%")
    end
  end

  # Returns an array of status values matching the search term.
  def matching_status_values(term)
    JobLead.statuses.filter_map do |key, value|
      value if key.tr('_', ' ').downcase.include?(term)
    end
  end
end
