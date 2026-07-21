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
