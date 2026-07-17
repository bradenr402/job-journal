require "test_helper"
require "minitest/mock"

class JobLeadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user

    @job_lead = job_leads(:one)
  end

  test "should get index" do
    get job_leads_url
    assert_response :success
  end

  test "should get new" do
    get new_job_lead_url
    assert_response :success
  end

  test "should create job_lead" do
    assert_difference("JobLead.count") do
      post job_leads_url, params: { job_lead: { title: "New Job", company: "New Co", application_url: "https://example.com" } }
    end

    assert_redirected_to job_lead_url(JobLead.last)
  end

  test "should show job_lead" do
    get job_lead_url(@job_lead)
    assert_response :success
  end

  test "should get edit" do
    get edit_job_lead_url(@job_lead)
    assert_response :success
  end

  test "should update job_lead" do
    patch job_lead_url(@job_lead), params: { job_lead: { title: "Updated Title" } }
    assert_redirected_to job_lead_url(@job_lead)
  end

  test "should destroy job_lead" do
    assert_difference("JobLead.count", -1) do
      delete job_lead_url(@job_lead)
    end

    assert_redirected_to job_leads_url
  end

  test "should archive job_lead" do
    patch archive_job_lead_url(@job_lead)
    assert @job_lead.reload.archived?
  end

  test "should unarchive job_lead" do
    @job_lead.archive!

    patch unarchive_job_lead_url(@job_lead)
    assert @job_lead.reload.active?
  end

  test "should advance and revert status" do
    freeze_time

    lead = @user.job_leads.create(title: "Example", company: "Example co.", application_url: "https://example.com/jobs")

    patch advance_status_job_lead_url(lead)
    assert_equal lead.reload.status, "applied"

    lead.interviews.create(interviewer: "John Doe", scheduled_at: 1.day.from_now)
    assert_equal lead.reload.status, "interview"

    lead.update(offer_amount: 100_000, offer_at: Time.current)
    assert_equal lead.reload.status, "offer"

    patch advance_status_job_lead_url(lead)
    assert_equal lead.reload.status, "accepted"

    patch revert_status_job_lead_url(lead)
    assert_equal lead.reload.status, "offer"

    patch revert_status_job_lead_url(lead)
    assert_equal lead.reload.status, "interview"

    patch revert_status_job_lead_url(lead)
    assert_equal lead.reload.status, "applied"
    assert_empty lead.interviews

    patch revert_status_job_lead_url(lead)
    assert_equal lead.reload.status, "lead"
  end

  test "should reject job_lead and revert to previous status" do
    lead = @user.job_leads.create(title: "Example", company: "Example co.", application_url: "https://example.com/jobs", applied_at: Time.current)
    previous_status = lead.status

    patch reject_job_lead_url(lead)
    assert_equal lead.reload.status, "rejected"

    patch revert_status_job_lead_url(lead)
    assert_equal lead.reload.status, previous_status
  end

  test "should get offer" do
    lead = @user.job_leads.create(title: "Example", company: "Example co.", application_url: "https://example.com/jobs")

    get offer_job_lead_url(lead)
    assert_redirected_to job_lead_url(lead)
    assert_equal flash[:alert], "Cannot advance to Offer before applying."

    lead.applied!
    get offer_job_lead_url(lead)
    assert_redirected_to job_lead_url(lead)
    assert_equal flash[:alert], "Cannot advance to Offer before interviewing."

    lead.interviews.create(interviewer: "John Doe", scheduled_at: 1.day.from_now)
    get offer_job_lead_url(lead)
    assert_response :success
    assert_nil flash[:alert]

    travel 1.week
    lead.update(offer_amount: 100_000, offer_at: Time.current)
    get offer_job_lead_url(lead)
    assert_redirected_to job_lead_url(lead)
    assert_equal flash[:alert], "Job lead is already in Offer stage."

    lead.accepted!
    get offer_job_lead_url(lead)
    assert_redirected_to job_lead_url(lead)
    assert_equal flash[:alert], "Job lead is already in Accepted stage."

    lead.update(accepted_at: nil)
    lead.rejected!
    get offer_job_lead_url(lead)
    assert_redirected_to job_lead_url(lead)
    assert_equal flash[:alert], "Cannot advance rejected lead to Offer."
  end

  test "should set offer on job_lead" do
    lead = @user.job_leads.create(title: "Example", company: "Example co.", application_url: "https://example.com/jobs")

    patch set_offer_job_lead_url(lead), params: { job_lead: { offer_amount: 120_000 } }
    assert_redirected_to job_lead_url(lead)
    assert_equal flash[:alert], "Cannot advance to Offer before applying."

    lead.applied!
    patch set_offer_job_lead_url(lead), params: { job_lead: { offer_amount: 120_000 } }
    assert_redirected_to job_lead_url(lead)
    assert_equal flash[:alert], "Cannot advance to Offer before interviewing."

    lead.interviews.create(interviewer: "John Doe", scheduled_at: 1.day.from_now)
    travel 1.week
    patch set_offer_job_lead_url(lead), params: { job_lead: { offer_amount: 120_000 } }
    assert_redirected_to job_lead_url(lead)
    assert_equal lead.reload.offer_amount, 120_000
    assert_equal lead.reload.status, "offer"
    assert_nil flash[:alert]

    patch set_offer_job_lead_url(lead), params: { job_lead: { offer_amount: 130_000 } }
    assert_redirected_to job_lead_url(lead)
    assert_equal flash[:alert], "Job lead is already in Offer stage."

    lead.accepted!
    patch set_offer_job_lead_url(lead), params: { job_lead: { offer_amount: 140_000 } }
    assert_redirected_to job_lead_url(lead)
    assert_equal flash[:alert], "Job lead is already in Accepted stage."

    lead.update(accepted_at: nil)
    lead.rejected!
    patch set_offer_job_lead_url(lead), params: { job_lead: { offer_amount: 150_000 } }
    assert_redirected_to job_lead_url(lead)
    assert_equal flash[:alert], "Cannot advance rejected lead to Offer."
  end

  test "should get history" do
    get history_job_lead_url(@job_lead)
    assert_response :success
  end

  test "should update history on job_lead" do
    lead = @user.job_leads.create!(
      title: "Example",
      company: "Example co.",
      application_url: "https://example.com/jobs",
      applied_at: 3.days.ago
    )

    interview = lead.interviews.create!(
      interviewer: "Jane Doe",
      scheduled_at: 2.days.ago
    )

    patch update_history_job_lead_url(lead), params: {
      job_lead: {
        applied_at: 5.days.ago,
        interviews_attributes: [
          { id: interview.id, scheduled_at: 4.days.ago }
        ]
      }
    }

    assert_redirected_to job_lead_url(lead)
    lead.reload
    assert_equal 5.days.ago.to_date, lead.applied_at.to_date
    assert_equal 4.days.ago.to_date, lead.interviews.first.scheduled_at.to_date
  end

  test "autofill returns parsed fields as JSON on success" do
    url = "https://www.linkedin.com/jobs/view/123"
    fields = { title: "Engineer", company: "Acme", source: "LinkedIn" }
    result = JobLeadAutofillFromUrl::Result.new(success?: true, fields: fields, error: nil)

    JobLeadAutofillFromUrl.stub :call, ->(passed) { assert_equal url, passed; result } do
      post autofill_job_leads_url, params: { url: }, as: :json
    end

    assert_response :success
    body = JSON.parse response.body, symbolize_names: true
    assert_equal "Engineer", body[:fields][:title]
    assert_equal "Acme", body[:fields][:company]
  end

  test "autofill falls back to the user-provided URL when the parser does not return one" do
    url = "https://www.linkedin.com/jobs/view/123"
    result = JobLeadAutofillFromUrl::Result.new(success?: true, fields: { title: "Engineer" }, error: nil)

    JobLeadAutofillFromUrl.stub :call, result do
      post autofill_job_leads_url, params: { url: }, as: :json
    end

    assert_response :success
    body = JSON.parse response.body, symbolize_names: true
    assert_equal url, body[:fields][:application_url]
  end

  test "autofill keeps the parsed application_url when present" do
    url = "https://www.linkedin.com/jobs/view/123"
    parsed_url = "https://www.linkedin.com/jobs/view/123/canonical"
    result = JobLeadAutofillFromUrl::Result.new(
      success?: true,
      fields: { title: "Engineer", application_url: parsed_url },
      error: nil
    )

    JobLeadAutofillFromUrl.stub :call, result do
      post autofill_job_leads_url, params: { url: }, as: :json
    end

    assert_response :success
    body = JSON.parse response.body, symbolize_names: true
    assert_equal parsed_url, body[:fields][:application_url]
  end

  test "autofill returns 422 with the service error message on failure" do
    result = JobLeadAutofillFromUrl::Result.new(success?: false, fields: {}, error: "That host is not supported yet.")

    JobLeadAutofillFromUrl.stub :call, result do
      post autofill_job_leads_url, params: { url: "https://example.com" }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse response.body, symbolize_names: true
    assert_equal "That host is not supported yet.", body[:error]
  end

  test "autofill requires authentication" do
    delete session_url if respond_to?(:session_url)
    cookies.delete(Authentication::SESSION_COOKIE_NAME)
    Current.session = nil

    post autofill_job_leads_url, params: { url: "https://www.linkedin.com/jobs/view/123" }, as: :json

    assert_not_equal 200, response.status
  end
end
