class InterviewsController < ApplicationController
  before_action :set_interview, only: %i[ show edit update destroy ]

  # GET /interviews
  def index
    scope = Current.user.interviews
      .includes(:job_lead, :notes)
      .select(
        :id,
        :created_at,
        :updated_at,
        :job_lead_id,
        :interviewer,
        :scheduled_at,
        :location
      )

    @interviews =
      if params[:scheduled] == 'upcoming'
        scope.future.order(scheduled_at: :desc)
      elsif params[:scheduled] == 'completed'
        scope.past.order(scheduled_at: :desc)
      else
        scope.order(scheduled_at: :desc)
      end
  end

  # GET /interviews/1
  def show
    @job_lead = @interview.job_lead
    @notes = @interview.notes.order(updated_at: :desc)
  end

  # GET /interviews/new
  def new
    @interview = Interview.new(job_lead_id: params[:job_lead_id].presence)
  end

  # GET /interviews/1/edit
  def edit
  end

  # POST /interviews
  def create
    @interview = Interview.new(interview_params)

    if @interview.save
      redirect_to @interview, success: 'Interview was successfully created.'
    else
      render :new, status: :unprocessable_entity, error: 'Failed to create the interview.'
    end
  end

  # PATCH/PUT /interviews/1
  def update
    if @interview.update(interview_params)
      redirect_to @interview, success: 'Interview was successfully updated.', status: :see_other
    else
      render :edit, status: :unprocessable_entity, error: 'Failed to update the interview.'
    end
  end

  # DELETE /interviews/1
  def destroy
    if @interview.destroy
      redirect_to @interview.job_lead, success: 'Interview was successfully destroyed.', status: :see_other
    else
      redirect_to @interview, error: 'Failed to destroy the interview.', status: :unprocessable_entity
    end
  end

  private
  def set_interview
    @interview = Current.user.interviews.includes(:job_lead, :notes).find(params.expect(:id))
  rescue ActiveRecord::RecordNotFound
    redirect_back fallback_location: root_path, alert: 'Interview not found.', status: :not_found
  end

  def interview_params
    params.expect(interview: [ :job_lead_id, :interviewer, :scheduled_at, :location, :rating, :call_url ])
  end
end
