require 'test_helper'

class JobLeadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user

    @job_lead = job_leads(:one)
  end

  test 'should get index' do
    get job_leads_url
    assert_response :success
  end

  test 'should get new' do
    get new_job_lead_url
    assert_response :success
  end

  test 'should create job_lead' do
    assert_difference('JobLead.count') do
      post job_leads_url, params: { job_lead: { title: 'New Job', company: 'New Co', application_url: 'https://example.com' } }
    end

    assert_redirected_to job_lead_url(JobLead.last)
  end

  test 'should show job_lead' do
    get job_lead_url(@job_lead)
    assert_response :success
  end

  test 'should get edit' do
    get edit_job_lead_url(@job_lead)
    assert_response :success
  end

  test 'should update job_lead' do
    patch job_lead_url(@job_lead), params: { job_lead: { title: 'Updated Title' } }
    assert_redirected_to job_lead_url(@job_lead)
  end

  test 'should destroy job_lead' do
    assert_difference('JobLead.count', -1) do
      delete job_lead_url(@job_lead)
    end

    assert_redirected_to job_leads_url
  end
end
