class SearchController < ApplicationController
  def index
    @selected_filter = params[:filter].presence || 'all'

    selected_status_name = params[:status].presence

    @all_status_names = JobLead.statuses.keys.map(&:to_s)
    @selected_status = selected_status_name if @all_status_names.include?(selected_status_name)

    @selected_date_range_param = params[:date_range].presence

    all_date_ranges = [ 'upcoming', 'past' ]
    @selected_date_range = @selected_date_range_param if all_date_ranges.include?(@selected_date_range_param)
    @unselected_date_ranges = all_date_ranges - [ @selected_date_range ].compact

    @selected_notable_type_param = params[:notable_type].presence

    all_notable_types = [ 'JobLead', 'Interview' ]
    @selected_notable_type = @selected_notable_type_param if all_notable_types.include?(@selected_notable_type_param)
    @unselected_notable_types = all_notable_types - [ @selected_notable_type ].compact

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
end
