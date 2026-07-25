class SearchController < ApplicationController
  def index
    @search_scopes = SearchQuery::SCOPES
    @query = params[:q]

    @job_lead_filters = JobLeadFilters.new(params, user: Current.user)
    @interview_filters = InterviewFilters.new(params, user: Current.user)
    @note_filters = NoteFilters.new(params, user: Current.user)

    @statuses = JobLeadFilters.options_for(:status)
    @timeframes = InterviewFilters.options_for(:timeframe).without("all")
    @notable_types = NoteFilters.options_for(:notable_type)

    search_filters = {
      job_leads: @job_lead_filters,
      interviews: @interview_filters,
      notes: @note_filters
    }

    search_query = SearchQuery.new(Current.user, @query, scope: params[:scope], filters: search_filters)
    @search_scope = search_query.scope
    @results = search_query.results

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
end
