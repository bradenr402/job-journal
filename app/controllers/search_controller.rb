class SearchController < ApplicationController
  FILTERS = %w[ all job_leads interviews notes ].freeze

  def index
    @all_filters = FILTERS
    @selected_filter = valid_filter

    @all_status_names = JobLead::STATUSES
    @selected_status = valid_status

    @all_date_ranges = User::Settings::SCHEMA.dig(:filters, :interviews, :allowed).without("all")
    @selected_date_range = valid_date_range.presence_in(@all_date_ranges)

    @all_notable_types = %w[ JobLead Interview ]
    @selected_notable_type = valid_notable_type

    @query = params[:q]
    @results = SearchQuery.new(
      Current.user,
      @query,
      filter: @selected_filter,
      status: @selected_status,
      date_range: @selected_date_range,
      notable_type: @selected_notable_type
    ).results

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private

  def valid_filter
    filter = params[:filter]
    filter.in?(FILTERS) ? filter : "all"
  end
end
