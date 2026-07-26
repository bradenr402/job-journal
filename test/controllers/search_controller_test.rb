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

  test "should default to all scope when scope param is invalid" do
    get search_url(q: "anything", scope: "bogus")

    assert_response :success
    assert_select "#search-filters a.dropdown-option-selected", text: "All"
  end

  test "should filter search results by status" do
    applied = create_job_lead(title: "Quantumly Applied Role", applied_at: 1.day.ago)
    new_lead = create_job_lead(title: "Quantumly Lead Role")
    get search_url(q: "Quantumly", scope: "job_leads", status: "applied")

    assert_response :success
    assert_select "#job_lead_#{applied.id}"
    assert_select "#job_lead_#{new_lead.id}", false
  end

  test "should ignore an invalid status param" do
    applied = create_job_lead(title: "Quantumly Applied Role", applied_at: 1.day.ago)
    new_lead = create_job_lead(title: "Quantumly Lead Role")
    get search_url(q: "Quantumly", scope: "job_leads", status: "bogus")

    assert_response :success
    assert_select "#job_lead_#{applied.id}"
    assert_select "#job_lead_#{new_lead.id}"
  end

  test "should filter search results by source" do
    linkedin = create_job_lead(title: "Quantumly LinkedIn Role", source: "LinkedIn")
    indeed = create_job_lead(title: "Quantumly Indeed Role", source: "Indeed")
    get search_url(q: "Quantumly", scope: "job_leads", source: "linkedin")

    assert_response :success
    assert_select "#job_lead_#{linkedin.id}"
    assert_select "#job_lead_#{indeed.id}", false
  end

  test "should filter search results by rating" do
    rated = create_interview(interviewer: "Wendy Rated", rating: 4, scheduled_at: 1.day.ago)
    unrated = create_interview(interviewer: "Wendy Unrated", scheduled_at: 1.day.ago)
    get search_url(q: "Wendy", scope: "interviews", rating: "4")

    assert_response :success
    assert_select "#interview_#{rated.id}"
    assert_select "#interview_#{unrated.id}", false
  end

  test "should filter search results by timeframe" do
    completed = create_interview(interviewer: "Wendy Bygone", scheduled_at: 1.day.ago)
    upcoming = create_interview(interviewer: "Wendy Hence", scheduled_at: 1.day.from_now)

    get search_url(q: "Wendy", scope: "interviews", timeframe: "completed")
    assert_response :success
    assert_select "#interview_#{completed.id}"
    assert_select "#interview_#{upcoming.id}", false

    get search_url(q: "Wendy", scope: "interviews", timeframe: "upcoming")
    assert_response :success
    assert_select "#interview_#{upcoming.id}"
    assert_select "#interview_#{completed.id}", false
  end

  test "should not apply user interviews filter setting to search" do
    @user.update_settings(filters: { interviews: "upcoming" })
    completed = create_interview(interviewer: "Wendy Bygone", scheduled_at: 1.day.ago)
    upcoming = create_interview(interviewer: "Wendy Hence", scheduled_at: 1.day.from_now)
    get search_url(q: "Wendy", scope: "interviews")

    assert_response :success
    assert_select "#interview_#{completed.id}"
    assert_select "#interview_#{upcoming.id}"
  end

  test "should not apply user interviews filter setting when date range param is invalid" do
    @user.update_settings(filters: { interviews: "upcoming" })
    completed = create_interview(interviewer: "Wendy Bygone", scheduled_at: 1.day.ago)
    upcoming = create_interview(interviewer: "Wendy Hence", scheduled_at: 1.day.from_now)
    get search_url(q: "Wendy", scope: "interviews", timeframe: "bogus")

    assert_response :success
    assert_select "#interview_#{completed.id}"
    assert_select "#interview_#{upcoming.id}"
  end

  test "should filter search results by notable type" do
    job_lead_note = create_note(notable: job_leads(:one), content: "Xylophone melody on the lead")
    interview_note = create_note(notable: interviews(:one), content: "Xylophone melody on the interview")

    get search_url(q: "Xylophone", scope: "notes", notable_type: "JobLead")
    assert_response :success
    assert_select "#note_#{job_lead_note.id}"
    assert_select "#note_#{interview_note.id}", false

    get search_url(q: "Xylophone", scope: "notes", notable_type: "Interview")
    assert_response :success
    assert_select "#note_#{interview_note.id}"
    assert_select "#note_#{job_lead_note.id}", false
  end

  test "should ignore an invalid notable type param" do
    job_lead_note = create_note(notable: job_leads(:one), content: "Xylophone melody on the lead")
    interview_note = create_note(notable: interviews(:one), content: "Xylophone melody on the interview")
    get search_url(q: "Xylophone", scope: "notes", notable_type: "Bogus")

    assert_response :success
    assert_select "#note_#{job_lead_note.id}"
    assert_select "#note_#{interview_note.id}"
  end
end
