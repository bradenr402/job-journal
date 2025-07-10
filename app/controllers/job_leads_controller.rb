class JobLeadsController < ApplicationController
  before_action :set_job_lead, only: [ :show, :edit, :update, :destroy, :archive, :unarchive ]
  before_action :cleanup_tags, only: [ :index, :new, :edit ]

  # GET /job_leads
  def index
    @tags = Current.user.tags.order(:name)

    @selected_tag_names = params[:tags].to_s.split(',').map(&:strip).uniq
    @selected_status_name = params[:status].presence

    @job_leads = Current.user.job_leads
    @job_leads =
      if params[:archived] == 'true'
        @job_leads.archived.order(archived_at: :desc)
      else
        @job_leads.active.order(updated_at: :desc)
      end

    @job_leads = @job_leads.with_tags(@selected_tag_names) if @selected_tag_names.present?
    @job_leads = @job_leads.where(status: @selected_status_name) if @selected_status_name.present?

    @selected_tags = @tags.select { it.name.in? @selected_tag_names }
    @unselected_tags = @tags - @selected_tags

    all_status_names = JobLead.statuses.keys.map(&:to_s)
    @selected_status = @selected_status_name if all_status_names.include?(@selected_status_name)
    @unselected_statuses = all_status_names - [ @selected_status_name ].compact
  end

  # GET /job_leads/1
  def show
    @notes = @job_lead.notes.order(updated_at: :desc)
    @interviews = @job_lead.interviews.order(scheduled_at: :desc)
  end

  # GET /job_leads/new
  def new
    @job_lead = Current.user.job_leads.build

    set_recents
    @tags = Current.user.tags.order(:name)
  end

  # GET /job_leads/1/edit
  def edit
    set_recents
    @tags = Current.user.tags.order(:name)
  end

  # POST /job_leads
  def create
    @job_lead = Current.user.job_leads.build(job_lead_params)
    @tags = Current.user.tags.order(:name)

    if @job_lead.save
      redirect_to @job_lead, success: 'Job lead was successfully created.'
    else
      set_recents
      render :new, status: :unprocessable_entity, error: 'Failed to create job lead.'
    end
  end

  # PATCH/PUT /job_leads/1
  def update
    if @job_lead.update(job_lead_params)
      flash[:notice] = 'Job lead automatically archived.' if @job_lead.rejected? && @job_lead.archived_at.after?(10.seconds.ago)
      redirect_to @job_lead, success: 'Job lead was successfully updated.'
    else
      set_recents
      render :edit, status: :unprocessable_entity, error: 'Failed to update job lead.'
    end
  end

  # DELETE /job_leads/1
  def destroy
    if @job_lead.destroy
      redirect_to job_leads_path, status: :see_other, success: 'Job lead was successfully destroyed.'
    else
      redirect_to @job_lead, error: 'Failed to destroy job lead.'
    end
  end

  # PATCH /job_leads/1/archive
  def archive
    if @job_lead.archive!
      redirect_to @job_lead, success: 'Job lead was archived.'
    else
      redirect_to @job_lead, error: 'Failed to archive job lead.'
    end
  end

  # PATCH /job_leads/1/unarchive
  def unarchive
    if @job_lead.unarchive!
      redirect_to @job_lead, success: 'Job lead was unarchived.'
    else
      redirect_to @job_lead, error: 'Failed to unarchive job lead.'
    end
  end

  private

  def set_job_lead
    @job_lead = JobLead.find(params.expect(:id))
  rescue ActiveRecord::RecordNotFound
    redirect_back fallback_location: root_path, alert: 'Job lead not found.', status: :not_found
  end

  def job_lead_params
    params.expect(job_lead: [ :title, :company, :application_url, :source, :salary, :contact, :offer_amount, :location, :status, :tag_list ])
  end

  def cleanup_tags
    Tag.cleanup_unused_for_user(Current.user)
  end

  def set_recents
    @recent_companies = Current.user.job_leads.where(created_at: 30.days.ago..).distinct.pluck(:company).sort
    @recent_locations = Current.user.job_leads.where(created_at: 30.days.ago..).where.not(location: [ nil, '' ]).distinct.pluck(:location).sort
    @recent_sources = Current.user.job_leads.where(created_at: 30.days.ago..).where.not(source: [ nil, '' ]).distinct.pluck(:source).sort
  end
end
