class JobLeadsController < ApplicationController
  before_action :set_job_lead, only: [ :show, :edit, :update, :destroy, :archive, :unarchive ]

  # GET /job_leads
  def index
    @job_leads =
      if params[:archived] == 'true'
        Current.user.job_leads.archived.order(archived_at: :desc)
      else
        Current.user.job_leads.active.order(updated_at: :desc)
      end
  end

  # GET /job_leads/1
  def show
    @notes = @job_lead.notes.order(updated_at: :desc)
    @interviews = @job_lead.interviews.order(scheduled_at: :desc)
    # @applications = @job_lead.applications.order(applied_at: :desc)
  end

  # GET /job_leads/new
  def new
    @job_lead = Current.user.job_leads.build

    set_recents
  end

  # GET /job_leads/1/edit
  def edit
    set_recents
  end

  # POST /job_leads
  def create
    @job_lead = Current.user.job_leads.build(job_lead_params)

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
    params.expect(job_lead: [ :title, :company, :application_url, :source, :salary, :contact, :offer_amount, :location, :status ])
  end

  def set_recents
    @recent_companies = Current.user.job_leads.where(created_at: 30.days.ago..).distinct.pluck(:company).sort
    @recent_locations = Current.user.job_leads.where(created_at: 30.days.ago..).where.not(location: [ nil, '' ]).distinct.pluck(:location).sort
    @recent_sources = Current.user.job_leads.where(created_at: 30.days.ago..).where.not(source: [ nil, '' ]).distinct.pluck(:source).sort
  end
end
