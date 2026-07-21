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

    @selected_interview_type = params[:scheduled].presence || Current.user.get_setting(:filters, :interviews)

    @interviews =
      case @selected_interview_type
      when "upcoming" then scope.future.order(scheduled_at: :desc)
      when "completed" then scope.past.order(scheduled_at: :desc)
      else scope.order(scheduled_at: :desc)
      end
  end

  # GET /interviews/1
  def show
    @job_lead = @interview.job_lead
    @notes = @interview.notes.order(updated_at: :desc)
  end

  # GET /interviews/new
  def new
    job_lead = Current.user.job_leads.find_by(id: params[:job_lead_id])
    return redirect_to job_leads_path, error: "Job lead not found." unless job_lead

    unless job_lead&.interviewable?
      return redirect_to job_lead, alert: "Cannot create an interview for a job lead that is in the '#{job_lead.status.humanize}' status."
    end

    @interview = Interview.new(job_lead_id: params[:job_lead_id].presence)
  end

  # GET /interviews/1/edit
  def edit
  end

  # POST /interviews
  def create
    job_lead = Current.user.job_leads.find_by(id: interview_params[:job_lead_id])
    return redirect_to job_leads_path, error: "Job lead not found." unless job_lead

    @interview = job_lead.interviews.new(interview_params)

    if @interview.save
      redirect_to @interview, success: "Interview was successfully created."
    else
      render :new, status: :unprocessable_content, error: "Failed to create the interview."
    end
  end

  # PATCH/PUT /interviews/1
  def update
    if interview_params[:job_lead_id].present? && !Current.user.job_leads.exists?(interview_params[:job_lead_id])
      return redirect_to job_leads_path, error: "Job lead not found."
    end

    if @interview.update(interview_params)
      redirect_to @interview, success: "Interview was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content, error: "Failed to update the interview."
    end
  end

  # DELETE /interviews/1
  def destroy
    if @interview.destroy
      redirect_to @interview.job_lead, success: "Interview was successfully deleted.", status: :see_other
    else
      redirect_to @interview, error: "Failed to delete the interview.", status: :unprocessable_content
    end
  end

  # GET /interviews/:id/add_to_calendar
  def add_to_calendar
    event = @interview.calendar_event(request)

    calendar = Icalendar::Calendar.new
    calendar.add_event(event)
    calendar.publish

    send_data calendar.to_ical,
              filename: "#{@interview.title.parameterize}-#{@interview.scheduled_at.to_date}.ics",
              type: "text/calendar",
              disposition: "inline"
  end

  private

  def set_interview
    @interview = Current.user.interviews.includes(:job_lead, :notes).find(params.expect(:id))
  rescue ActiveRecord::RecordNotFound
    flash[:error] = "Interview not found."
    raise # Let config.exceptions_app handle the error
  end

  def interview_params
    params.expect(interview: [ :job_lead_id, :interviewer, :scheduled_at, :location, :rating, :call_url ])
  end
end
