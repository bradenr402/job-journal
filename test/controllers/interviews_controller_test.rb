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

  test "should filter index by upcoming timeframe" do
    completed = create_interview(interviewer: "Wendy Bygone", scheduled_at: 1.day.ago)
    upcoming = create_interview(interviewer: "Wendy Hence", scheduled_at: 1.day.from_now)
    get interviews_url(timeframe: "upcoming")

    assert_response :success
    assert_select "#interview_#{upcoming.id}"
    assert_select "#interview_#{completed.id}", false
  end

  test "should filter index by completed timeframe" do
    completed = create_interview(interviewer: "Wendy Bygone", scheduled_at: 1.day.ago)
    upcoming = create_interview(interviewer: "Wendy Hence", scheduled_at: 1.day.from_now)
    get interviews_url(timeframe: "completed")

    assert_response :success
    assert_select "#interview_#{completed.id}"
    assert_select "#interview_#{upcoming.id}", false
  end

  test "should fall back to user setting when timeframe param is missing" do
    @user.update_settings(filters: { interviews: "upcoming" })
    completed = create_interview(interviewer: "Wendy Bygone", scheduled_at: 1.day.ago)
    upcoming = create_interview(interviewer: "Wendy Hence", scheduled_at: 1.day.from_now)
    get interviews_url

    assert_response :success
    assert_select "#interview_#{upcoming.id}"
    assert_select "#interview_#{completed.id}", false
  end

  test "should fall back to user setting when timeframe param is invalid" do
    @user.update_settings(filters: { interviews: "completed" })
    completed = create_interview(interviewer: "Wendy Bygone", scheduled_at: 1.day.ago)
    upcoming = create_interview(interviewer: "Wendy Hence", scheduled_at: 1.day.from_now)
    get interviews_url(timeframe: "bogus")

    assert_response :success
    assert_select "#interview_#{completed.id}"
    assert_select "#interview_#{upcoming.id}", false
  end

  test "should override user setting with a valid timeframe param" do
    @user.update_settings(filters: { interviews: "upcoming" })
    completed = create_interview(interviewer: "Wendy Bygone", scheduled_at: 1.day.ago)
    upcoming = create_interview(interviewer: "Wendy Hence", scheduled_at: 1.day.from_now)
    get interviews_url(timeframe: "all")

    assert_response :success
    assert_select "#interview_#{completed.id}"
    assert_select "#interview_#{upcoming.id}"
  end

  test "should preserve an explicit timeframe override in filter and sort links" do
    @user.update_settings(filters: { interviews: "upcoming" })
    get interviews_url(timeframe: "all")

    assert_response :success
    assert_select "a[href*='timeframe=all'][href*='rating=5']"
    assert_select "a[href*='timeframe=all'][href*='sort=interviewer']"
  end

  test "should filter index by rating" do
    rated = create_interview(interviewer: "Rated Rita", rating: 5, scheduled_at: 1.day.ago)
    unrated = create_interview(interviewer: "Unrated Uri", scheduled_at: 1.day.ago)
    get interviews_url(rating: "5")

    assert_response :success
    assert_select "#interview_#{rated.id}"
    assert_select "#interview_#{unrated.id}", false
  end

  test "should filter index by unrated" do
    rated = create_interview(interviewer: "Rated Rita", rating: 5, scheduled_at: 1.day.ago)
    unrated = create_interview(interviewer: "Unrated Uri", scheduled_at: 1.day.ago)
    get interviews_url(rating: "unrated")

    assert_response :success
    assert_select "#interview_#{unrated.id}"
    assert_select "#interview_#{rated.id}", false
  end

  test "should ignore an invalid rating param" do
    rated = create_interview(interviewer: "Rated Rita", rating: 5, scheduled_at: 1.day.ago)
    unrated = create_interview(interviewer: "Unrated Uri", scheduled_at: 1.day.ago)
    get interviews_url(rating: "bogus")

    assert_response :success
    assert_select "#interview_#{rated.id}"
    assert_select "#interview_#{unrated.id}"
  end

  test "should sort index by interviewer" do
    create_interview(interviewer: "Zzz Last Interviewer")
    create_interview(interviewer: "Aaa First Interviewer")

    get interviews_url(sort: "interviewer", direction: "asc")
    assert_response :success
    assert_match(/Aaa First Interviewer.*Zzz Last Interviewer/m, response.body)

    get interviews_url(sort: "interviewer", direction: "desc")
    assert_response :success
    assert_match(/Zzz Last Interviewer.*Aaa First Interviewer/m, response.body)
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
