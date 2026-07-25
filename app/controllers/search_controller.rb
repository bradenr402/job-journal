class SearchController < ApplicationController
  def index
    @search_scopes = SearchQuery::SCOPES
    @search_scope = params[:scope].to_s.presence_in(SearchQuery::SCOPES) || "all"

    @job_lead_filters = JobLeadFilters.new(params, user: Current.user)
    @interview_filters = InterviewFilters.new(params, user: Current.user)
    @note_filters = NoteFilters.new(params, user: Current.user)

    @statuses = JobLeadFilters.options_for(:status)
    @timeframes = InterviewFilters.options_for(:timeframe).without("all")
    @notable_types = NoteFilters.options_for(:notable_type)

    @query = params[:q]
    @results = SearchQuery.new(
      Current.user,
      @query,
      scope: @search_scope,
      filters: {
        job_leads: @job_lead_filters,
        interviews: @interview_filters,
        notes: @note_filters
      }
    ).results

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
end
