require 'test_helper'

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

  test 'should get index' do
    get notes_url
    assert_response :success
  end

  test 'should get new' do
    get new_note_url(notable_type: @note.notable.model_name, notable_id: @note.notable.id)
    assert_response :success
  end

  test 'should create note' do
    assert_difference('Note.count') do
      post notes_url, params: { note: { content: 'This is a test.', notable_id: @note.notable_id, notable_type: @note.notable_type } }
    end

    assert_redirected_to notable_url(Note.last.notable)
  end

  test 'should show note' do
    get note_url(@note)
    assert_response :success
  end

  test 'should get edit' do
    get edit_note_url(@note)
    assert_response :success
  end

  test 'should update note' do
    patch note_url(@note), params: { note: { content: 'This is a test.' } }
    assert_redirected_to note_url(@note)
  end

  test 'should destroy note' do
    notable = @note.notable
    assert_difference('Note.count', -1) do
      delete note_url(@note)
    end

    assert_redirected_to notable_url(notable)
  end
end
