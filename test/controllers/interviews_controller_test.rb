require 'test_helper'

class InterviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user

    @interview = interviews(:one)
  end

  test 'should get index' do
    get interviews_url
    assert_response :success
  end

  test 'should get new' do
    get new_interview_url(job_lead_id: @interview.job_lead.id)
    assert_response :success
  end

  test 'should create interview' do
    assert_difference('Interview.count') do
      post interviews_url, params: { interview: { interviewer: 'Jorge Manrubia', scheduled_at: Time.now, job_lead_id: @interview.job_lead_id } }
    end

    assert_redirected_to interview_url(Interview.last)
  end

  test 'should show interview' do
    get interview_url(@interview)
    assert_response :success
  end

  test 'should get edit' do
    get edit_interview_url(@interview)
    assert_response :success
  end

  test 'should update interview' do
    patch interview_url(@interview), params: { interview: { interviewer: 'DHH' } }
    assert_redirected_to interview_url(@interview)
  end

  test 'should destroy interview' do
    job_lead = @interview.job_lead
    assert_difference('Interview.count', -1) do
      delete interview_url(@interview)
    end

    assert_redirected_to job_lead_url(job_lead)
  end
end
