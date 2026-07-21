require "test_helper"

class InterviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user

    @interview = interviews(:one)
  end

  teardown do
    Interview.destroy_all
  end

  test "should get index" do
    get interviews_url
    assert_response :success
  end

  test "should get new" do
    get new_interview_url(job_lead_id: @interview.job_lead.id)
    assert_response :success
  end

  test "should not get new for job lead not in interview status" do
    job_lead = create_job_lead

    get new_interview_url(job_lead_id: job_lead.id)
    assert_redirected_to job_lead_url(job_lead)
    assert_equal flash[:alert], "Cannot create an interview for a job lead that is in the 'Lead' status."
  end

  test "should create interview" do
    assert_difference("Interview.count", 1) do
      post interviews_url, params: { interview: { interviewer: "Jorge Manrubia", scheduled_at: Time.now, job_lead_id: @interview.job_lead_id } }
    end

    assert_redirected_to interview_url(Interview.last)
  end

  test "should not create interview for another user's job lead" do
    sign_in_as users(:two)

    assert_no_difference("Interview.count") do
      post interviews_url, params: { interview: { interviewer: "Jorge Manrubia", scheduled_at: Time.now, job_lead_id: @interview.job_lead.id } }
    end

    assert_redirected_to job_leads_url
    assert_equal flash[:error], "Job lead not found."
  end

  test "should show interview" do
    get interview_url(@interview)
    assert_response :success
  end

  test "should not show interview for another user" do
    sign_in_as users(:two)

    get interview_url(@interview)
    assert_response :not_found
    assert_equal "Interview not found.", flash[:error]
  end

  test "should get edit" do
    get edit_interview_url(@interview)
    assert_response :success
  end

  test "should not get edit for another user's interview" do
    sign_in_as users(:two)

    get edit_interview_url(@interview)
    assert_response :not_found
    assert_equal "Interview not found.", flash[:error]
  end

  test "should update interview" do
    patch interview_url(@interview), params: { interview: { interviewer: "DHH" } }
    assert_redirected_to interview_url(@interview)
  end

  test "should not update another user's interview" do
    sign_in_as users(:two)

    patch interview_url(@interview), params: { interview: { interviewer: "DHH" } }
    assert_response :not_found
    assert_equal "Interview not found.", flash[:error]
  end

  test "should not update interview to another user's job lead" do
    original_job_lead_id = @interview.job_lead_id

    patch interview_url(@interview), params: { interview: { interviewer: "DHH", job_lead_id: job_leads(:two).id } }
    assert_redirected_to job_leads_url
    assert_equal "Job lead not found.", flash[:error]
    assert_equal original_job_lead_id, @interview.reload.job_lead_id
  end

  test "should destroy interview" do
    job_lead = @interview.job_lead
    assert_difference("Interview.count", -1) do
      delete interview_url(@interview)
    end

    assert_redirected_to job_lead_url(job_lead)
  end

  test "should not destroy another user's interview" do
    sign_in_as users(:two)

    assert_no_difference("Interview.count") do
      delete interview_url(@interview)
    end

    assert_response :not_found
    assert_equal "Interview not found.", flash[:error]
  end

  test "should get add_to_calendar" do
    get add_to_calendar_interview_url(@interview)

    assert_response :success
    assert_equal "text/calendar", @response.media_type
    assert_match(/BEGIN:VCALENDAR/, @response.body)

    calendar = Icalendar::Calendar.parse(@response.body).first
    event = calendar.events.first
    assert_includes @response.body, "DTSTART:#{@interview.scheduled_at.strftime("%Y%m%dT%H%M%S")}"
    assert_includes @response.body, "DTEND:#{@interview.scheduled_at.advance(hours: 1).strftime("%Y%m%dT%H%M%S")}"
    assert_equal @interview.title, event.summary.to_s
    assert_equal "JobJournal: #{calendar_interview_url(@interview)}", event.description.to_s
    assert_equal @interview.location, event.location.to_s
    assert_equal @interview.call_url, event.url.to_s
    assert_equal "interview-#{@interview.id}@#{calendar_request_host}", event.uid.to_s

    disposition = @response.headers["Content-Disposition"]
    assert_includes disposition, "inline"
    assert_includes disposition, "filename=\"#{@interview.title.parameterize}-#{@interview.scheduled_at.to_date}.ics\""
  end

  test "should not get add_to_calendar for another user's interview" do
    sign_in_as users(:two)

    get add_to_calendar_interview_url(@interview)

    assert_response :not_found
    assert_equal "Interview not found.", flash[:error]
  end

  private

  def calendar_interview_url(interview)
    Rails.application.routes.url_helpers.interview_url(
      interview,
      Rails.application.config.action_mailer.default_url_options
    )
  end

  def calendar_request_host
    URI.parse(add_to_calendar_interview_url(@interview)).host
  end
end
