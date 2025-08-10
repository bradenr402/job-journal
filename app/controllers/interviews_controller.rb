class InterviewsController < ApplicationController
  before_action :set_interview, only: %i[ show edit update destroy add_to_calendar ]

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

  # GET /interviews/:id/add_to_calendar
  def add_to_calendar
    calendar = Icalendar::Calendar.new
    event = Icalendar::Event.new
    event.dtstart = @interview.scheduled_at
    event.dtend = @interview.scheduled_at.advance(hours: 1)
    event.summary = @interview.title
    event.description = @interview.notes.map(&:content).join("\n") if @interview.notes.exists?
    event.location = @interview.location.presence
    event.url = @interview.call_url.presence
    event.uid = "interview-#{@interview.id}@#{request.host}"

    calendar.add_event(event)
    calendar.publish

    send_data calendar.to_ical,
              filename: "#{@interview.title.parameterize}-#{@interview.scheduled_at.to_date}.ics",
              type: 'text/calendar',
              disposition: 'inline'
  end

  private
  def set_interview
    @interview = Current.user.interviews.includes(:job_lead, :notes).find(params.expect(:id))
  rescue ActiveRecord::RecordNotFound
    raise # Let config.exceptions_app handle the error
  end

  def interview_params
    params.expect(interview: [ :job_lead_id, :interviewer, :scheduled_at, :location, :rating, :call_url ])
  end
end
