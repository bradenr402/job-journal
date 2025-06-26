class JobLeadsController < ApplicationController
  before_action :set_job_lead, only: [ :show, :edit, :update, :destroy, :archive ]

  # GET /job_leads
  def index
    if params[:archived] == 'true'
      @job_leads = JobLead.archived
    else
      @job_leads = JobLead.active
    end
  end

  # GET /job_leads/1
  def show
  end

  # GET /job_leads/new
  def new
    @job_lead = Current.user.job_leads.build
  end

  # GET /job_leads/1/edit
  def edit
  end

  # POST /job_leads
  def create
    @job_lead = Current.user.job_leads.build(job_lead_params)

    if @job_lead.save
      redirect_to @job_lead, notice: 'Job lead was successfully created.'
    else
      render :new, status: :unprocessable_entity, alert: 'Failed to create job lead.'
    end
  end

  # PATCH/PUT /job_leads/1
  def update
    if @job_lead.update(job_lead_params)
      redirect_to @job_lead, notice: 'Job lead was successfully updated.'
    else
      render :edit, status: :unprocessable_entity, alert: 'Failed to update job lead.'
    end
  end

  # DELETE /job_leads/1
  def destroy
    if @job_lead.destroy
      redirect_to job_leads_path, status: :see_other, notice: 'Job lead was successfully destroyed.'
    else
      redirect_to @job_lead, alert: 'Failed to destroy job lead.'
    end
  end

  # PATCH /job_leads/1/archive
  def archive
    if @job_lead.update(archived_at: Time.current)
      redirect_to @job_lead, notice: 'Job lead was archived.'
    else
      redirect_to @job_lead, alert: 'Failed to archive job lead.'
    end
  end

  # PATCH /job_leads/1/unarchive
  def unarchive
    if @job_lead.update(archived_at: nil)
      redirect_to @job_lead, notice: 'Job lead was unarchived.'
    else
      redirect_to @job_lead, alert: 'Failed to unarchive job lead.'
    end
  end

  private

  def set_job_lead
    @job_lead = JobLead.find(params.expect(:id))
  end

  def job_lead_params
    params.expect(job_lead: [ :title, :company, :application_url, :source, :salary, :contact, :offer_amount, :location, :status ])
  end
end
