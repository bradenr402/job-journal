require "application_system_test_case"

class JobLeadsTest < ApplicationSystemTestCase
  setup do
    @job_lead = job_leads(:one)
  end

  test "visiting the index" do
    visit job_leads_url
    assert_selector "h1", text: "Job leads"
  end

  test "should create job lead" do
    visit job_leads_url
    click_on "New job lead"

    click_on "Create Job lead"

    assert_text "Job lead was successfully created"
    click_on "Back"
  end

  test "should update Job lead" do
    visit job_lead_url(@job_lead)
    click_on "Edit this job lead", match: :first

    click_on "Update Job lead"

    assert_text "Job lead was successfully updated"
    click_on "Back"
  end

  test "should destroy Job lead" do
    visit job_lead_url(@job_lead)
    accept_confirm { click_on "Destroy this job lead", match: :first }

    assert_text "Job lead was successfully destroyed"
  end
end
