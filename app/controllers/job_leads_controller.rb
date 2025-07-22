class JobLeadsController < ApplicationController
  before_action :set_job_lead, only: [ :show, :edit, :update, :destroy, :archive, :unarchive, :advance_status, :revert_status, :offer, :set_offer, :reject ]
  before_action :cleanup_tags, only: [ :index, :new, :edit ]

  # GET /job_leads
  def index
    @tags = Current.user.tags.order(:name)

    @selected_tag_names = params[:tags].to_s.split(',').map(&:strip).uniq
    @selected_status_name = params[:status].presence
    @selected_job_lead_type = params[:job_lead_type].presence || 'active'

    scope = Current.user.job_leads
      .includes(:notes, :tags)
      .select(
        :id,
        :created_at,
        :updated_at,
        :applied_at,
        :offer_at,
        :rejected_at,
        :accepted_at,
        :archived_at,
        :title,
        :company,
        :application_url
      )

    @job_leads =
      case @selected_job_lead_type
      when 'active'
        scope.active.order(updated_at: :desc)
      when 'archived'
        scope.archived.order(archived_at: :desc)
      else
        scope.order(updated_at: :desc)
      end

    @job_leads = @job_leads.with_tags(@selected_tag_names) if @selected_tag_names.present?
    @job_leads = @job_leads.with_status(@selected_status_name) if @selected_status_name.present?

    @selected_tags = @tags.where(name: @selected_tag_names)
    @unselected_tags = @tags.where.not(name: @selected_tag_names)

    @all_status_names = JobLead::STATUSES
    @selected_status = @selected_status_name if @all_status_names.include?(@selected_status_name)
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

    if @job_lead.save
      redirect_to @job_lead, success: 'Job lead was successfully created.'
    else
      @tags = Current.user.tags.order(:name)
      set_recents
      render :new, status: :unprocessable_entity, error: 'Failed to create job lead.'
    end
  end

  # PATCH/PUT /job_leads/1
  def update
    if @job_lead.update(job_lead_params)
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

  def advance_status
    case @job_lead.status
    when 'lead'
      @job_lead.applied!
    when 'offer'
      @job_lead.accepted!
    end

    redirect_to @job_lead, success: "Status advanced to #{@job_lead.status.titlecase}."
  end

  def reject
    @job_lead.rejected!
    redirect_to @job_lead, notice: 'Job lead marked as Rejected and automatically archived.'
  end

  def revert_status
    case @job_lead.status
    when 'applied'
      @job_lead.update!(applied_at: nil)
    when 'interview'
      @job_lead.interviews.destroy_all
    when 'offer'
      @job_lead.update!(offer_at: nil, offer_amount: nil)
    when 'rejected'
      @job_lead.update!(rejected_at: nil)
    when 'accepted'
      @job_lead.update!(accepted_at: nil)
    end

    redirect_to @job_lead, notice: "Status reverted to #{@job_lead.status.titlecase}."
  end

  def offer
  end

  def set_offer
    offer_amount = params[:job_lead][:offer_amount].to_f

    return redirect_back fallback_location: @job_lead, alert: 'Offer amount is required.' unless offer_amount.positive?

    if @job_lead.update(offer_at: Time.current, offer_amount:)
      redirect_to @job_lead, success: 'Offer amount set successfully.'
    else
      render :offer, status: :unprocessable_entity, error: 'Failed to set offer amount.'
    end
  end

  private

  def set_job_lead
    @job_lead = Current.user.job_leads.includes(:notes, :tags, interviews: :notes).find(params.expect(:id))
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
    scope = Current.user.job_leads.where(created_at: 30.days.ago..)

    @recent_companies = scope.distinct.pluck(:company).sort
    @recent_locations = scope.where.not(location: [ nil, '' ]).distinct.pluck(:location).sort
    @recent_sources = scope.where.not(source: [ nil, '' ]).distinct.pluck(:source).sort
  end
end
