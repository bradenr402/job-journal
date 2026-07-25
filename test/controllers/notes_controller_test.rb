require "test_helper"

class NotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user

    @note = notes(:one)
  end

  def notable_url(notable)
    if notable.is_a? JobLead
      job_lead_url(notable)
    else
      interview_url(notable)
    end
  end

  test "should get index" do
    get notes_url
    assert_response :success
  end

  test "should filter index by notable type" do
    job_lead_note = create_note(notable: job_leads(:one), content: "Note about a job lead")
    interview_note = create_note(notable: interviews(:one), content: "Note about an interview")
    get notes_url(notable_type: "Interview")

    assert_response :success
    assert_select "#note_#{interview_note.id}"
    assert_select "#note_#{job_lead_note.id}", false

    get notes_url(notable_type: "JobLead")

    assert_response :success
    assert_select "#note_#{job_lead_note.id}"
    assert_select "#note_#{interview_note.id}", false
  end

  test "should ignore an invalid notable type param" do
    job_lead_note = create_note(notable: job_leads(:one), content: "Note about a job lead")
    interview_note = create_note(notable: interviews(:one), content: "Note about an interview")
    get notes_url(notable_type: "Bogus")

    assert_response :success
    assert_select "#note_#{job_lead_note.id}"
    assert_select "#note_#{interview_note.id}"
  end

  test "should filter index by job lead state" do
    archived_lead = create_job_lead(title: "Archived Lead", archived_at: 1.day.ago)
    archived_note = create_note(notable: archived_lead, content: "Note about an archived job lead")
    active_note = create_note(notable: job_leads(:one), content: "Note about an active job lead")

    get notes_url(job_lead_state: "archived")
    assert_response :success
    assert_select "#note_#{archived_note.id}"
    assert_select "#note_#{active_note.id}", false

    get notes_url(job_lead_state: "active")
    assert_response :success
    assert_select "#note_#{active_note.id}"
    assert_select "#note_#{archived_note.id}", false
  end

  test "should fall back to user setting when job lead state param is missing" do
    @user.update_settings(filters: { notes: "archived" })
    archived_lead = create_job_lead(title: "Archived Lead", archived_at: 1.day.ago)
    archived_note = create_note(notable: archived_lead, content: "Note about an archived job lead")
    active_note = create_note(notable: job_leads(:one), content: "Note about an active job lead")
    get notes_url

    assert_response :success
    assert_select "#note_#{archived_note.id}"
    assert_select "#note_#{active_note.id}", false
  end

  test "should fall back to user setting when job lead state param is invalid" do
    @user.update_settings(filters: { notes: "archived" })
    archived_lead = create_job_lead(title: "Archived Lead", archived_at: 1.day.ago)
    archived_note = create_note(notable: archived_lead, content: "Note about an archived job lead")
    active_note = create_note(notable: job_leads(:one), content: "Note about an active job lead")
    get notes_url(job_lead_state: "bogus")

    assert_response :success
    assert_select "#note_#{archived_note.id}"
    assert_select "#note_#{active_note.id}", false
  end

  test "should override user setting with a valid job lead state param" do
    @user.update_settings(filters: { notes: "archived" })
    archived_lead = create_job_lead(title: "Archived Lead", archived_at: 1.day.ago)
    archived_note = create_note(notable: archived_lead, content: "Note about an archived job lead")
    active_note = create_note(notable: job_leads(:one), content: "Note about an active job lead")
    get notes_url(job_lead_state: "all")

    assert_response :success
    assert_select "#note_#{archived_note.id}"
    assert_select "#note_#{active_note.id}"
  end

  test "should sort index by created timestamp" do
    create_note(content: "Chronologically ancient note", created_at: 3.days.ago)
    create_note(content: "Chronologically recent note")

    get notes_url(sort: "created", direction: "asc")
    assert_response :success
    assert_match(/Chronologically ancient note.*Chronologically recent note/m, response.body)

    get notes_url(sort: "created", direction: "desc")
    assert_response :success
    assert_match(/Chronologically recent note.*Chronologically ancient note/m, response.body)
  end

  test "should get new" do
    get new_note_url(notable_type: @note.notable.model_name, notable_id: @note.notable.id)
    assert_response :success
  end

  test "should not get new for another user's notable" do
    sign_in_as users(:two)

    get new_note_url(notable_type: "JobLead", notable_id: @note.notable_id)
    assert_response :not_found
  end

  test "should create note" do
    assert_difference("Note.count") do
      post notes_url, params: { note: { content: "This is a test.", notable_id: @note.notable_id, notable_type: @note.notable_type } }
    end

    assert_redirected_to note_url(Note.last)
  end

  test "should not create note for another user's job lead" do
    sign_in_as users(:two)

    assert_no_difference("Note.count") do
      post notes_url, params: { note: { content: "This is a test.", notable_id: job_leads(:one).id, notable_type: "JobLead" } }
    end

    assert_response :not_found
  end

  test "should not create note for another user's interview" do
    sign_in_as users(:two)

    assert_no_difference("Note.count") do
      post notes_url, params: { note: { content: "This is a test.", notable_id: interviews(:one).id, notable_type: "Interview" } }
    end

    assert_response :not_found
  end

  test "should not create note with an unsupported notable type" do
    assert_no_difference("Note.count") do
      post notes_url, params: { note: { content: "This is a test.", notable_id: users(:two).id, notable_type: "User" } }
    end

    assert_response :not_found
  end

  test "should show note" do
    get note_url(@note)
    assert_response :success
  end

  test "should not show note for another user" do
    sign_in_as users(:two)

    get note_url(@note)
    assert_response :not_found
  end

  test "should get edit" do
    get edit_note_url(@note)
    assert_response :success
  end

  test "should not get edit for another user's note" do
    sign_in_as users(:two)

    get edit_note_url(@note)
    assert_response :not_found
  end

  test "should update note" do
    patch note_url(@note), params: { note: { content: "This is a test." } }
    assert_redirected_to note_url(@note)
  end

  test "should not update another user's note" do
    sign_in_as users(:two)

    original_content = @note.content

    patch note_url(@note), params: { note: { content: "This is a test." } }
    assert_response :not_found
    assert_equal original_content, @note.reload.content
  end

  test "should not update note to another user's notable" do
    original_notable_id = @note.notable_id

    patch note_url(@note), params: { note: { content: "This is a test.", notable_id: job_leads(:two).id, notable_type: "JobLead" } }
    assert_response :not_found
    assert_equal original_notable_id, @note.reload.notable_id
  end

  test "should destroy note" do
    notable = @note.notable
    assert_difference("Note.count", -1) do
      delete note_url(@note)
    end

    assert_redirected_to notable_url(notable)
  end

  test "should not destroy another user's note" do
    sign_in_as users(:two)

    assert_no_difference("Note.count") do
      delete note_url(@note)
    end

    assert_response :not_found
  end
end
