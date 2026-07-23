require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "should get search" do
    get search_url
    assert_response :success
  end

  test "should default to all filter when filter param is invalid" do
    get search_url(q: "anything", filter: "bogus")

    assert_response :success
    assert_select "input#filter_all[checked]"
  end

  test "should filter search results by status" do
    applied = create_job_lead(title: "Quantumly Applied Role", applied_at: 1.day.ago)
    new_lead = create_job_lead(title: "Quantumly Lead Role")
    get search_url(q: "Quantumly", filter: "job_leads", status: "applied")

    assert_response :success
    assert_select "#job_lead_#{applied.id}"
    assert_select "#job_lead_#{new_lead.id}", false
  end

  test "should ignore an invalid status param" do
    applied = create_job_lead(title: "Quantumly Applied Role", applied_at: 1.day.ago)
    new_lead = create_job_lead(title: "Quantumly Lead Role")
    get search_url(q: "Quantumly", filter: "job_leads", status: "bogus")

    assert_response :success
    assert_select "#job_lead_#{applied.id}"
    assert_select "#job_lead_#{new_lead.id}"
  end

  test "should filter search results by date range" do
    completed = create_interview(interviewer: "Wendy Bygone", scheduled_at: 1.day.ago)
    upcoming = create_interview(interviewer: "Wendy Hence", scheduled_at: 1.day.from_now)
    get search_url(q: "Wendy", filter: "interviews", date_range: "completed")

    assert_response :success
    assert_select "#interview_#{completed.id}"
    assert_select "#interview_#{upcoming.id}", false

    get search_url(q: "Wendy", filter: "interviews", date_range: "upcoming")

    assert_response :success
    assert_select "#interview_#{upcoming.id}"
    assert_select "#interview_#{completed.id}", false
  end

  test "should not apply user interviews filter setting to search" do
    @user.update_settings(filters: { interviews: "upcoming" })
    completed = create_interview(interviewer: "Wendy Bygone", scheduled_at: 1.day.ago)
    upcoming = create_interview(interviewer: "Wendy Hence", scheduled_at: 1.day.from_now)
    get search_url(q: "Wendy", filter: "interviews")

    assert_response :success
    assert_select "#interview_#{completed.id}"
    assert_select "#interview_#{upcoming.id}"
  end

  test "should not apply user interviews filter setting when date range param is invalid" do
    @user.update_settings(filters: { interviews: "upcoming" })
    completed = create_interview(interviewer: "Wendy Bygone", scheduled_at: 1.day.ago)
    upcoming = create_interview(interviewer: "Wendy Hence", scheduled_at: 1.day.from_now)
    get search_url(q: "Wendy", filter: "interviews", date_range: "bogus")

    assert_response :success
    assert_select "#interview_#{completed.id}"
    assert_select "#interview_#{upcoming.id}"
  end

  test "should filter search results by notable type" do
    job_lead_note = create_note(notable: job_leads(:one), content: "Xylophone melody on the lead")
    interview_note = create_note(notable: interviews(:one), content: "Xylophone melody on the interview")
    get search_url(q: "Xylophone", filter: "notes", notable_type: "JobLead")

    assert_response :success
    assert_select "#note_#{job_lead_note.id}"
    assert_select "#note_#{interview_note.id}", false

    get search_url(q: "Xylophone", filter: "notes", notable_type: "Interview")

    assert_response :success
    assert_select "#note_#{interview_note.id}"
    assert_select "#note_#{job_lead_note.id}", false
  end

  test "should ignore an invalid notable type param" do
    job_lead_note = create_note(notable: job_leads(:one), content: "Xylophone melody on the lead")
    interview_note = create_note(notable: interviews(:one), content: "Xylophone melody on the interview")
    get search_url(q: "Xylophone", filter: "notes", notable_type: "Bogus")

    assert_response :success
    assert_select "#note_#{job_lead_note.id}"
    assert_select "#note_#{interview_note.id}"
  end
end
