class JobLeadsController < ApplicationController
  before_action :set_job_lead, only: %i[ show edit update destroy ]

  # GET /job_leads or /job_leads.json
  def index
    @job_leads = JobLead.all
  end

  # GET /job_leads/1 or /job_leads/1.json
  def show
  end

  # GET /job_leads/new
  def new
    @job_lead = Current.user.job_leads.build
  end

  # GET /job_leads/1/edit
  def edit
  end

  # POST /job_leads or /job_leads.json
  def create
    @job_lead = Current.user.job_leads.build(job_lead_params)

    respond_to do |format|
      if @job_lead.save
        format.html { redirect_to @job_lead, notice: 'Job lead was successfully created.' }
        format.json { render :show, status: :created, location: @job_lead }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @job_lead.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /job_leads/1 or /job_leads/1.json
  def update
    respond_to do |format|
      if @job_lead.update(job_lead_params)
        format.html { redirect_to @job_lead, notice: 'Job lead was successfully updated.' }
        format.json { render :show, status: :ok, location: @job_lead }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @job_lead.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /job_leads/1 or /job_leads/1.json
  def destroy
    @job_lead.destroy!

    respond_to do |format|
      format.html { redirect_to job_leads_path, status: :see_other, notice: 'Job lead was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_job_lead
      @job_lead = JobLead.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def job_lead_params
      params.expect(job_lead: [ :title, :company, :application_url, :source, :salary, :contact, :offer_amount, :location, :status ])
    end
end
