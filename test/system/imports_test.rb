require "application_system_test_case"

class ImportsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)

    # Import drafts live in the cache, which is a null store in tests.
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    visit new_session_url
    fill_in "Email Address", with: @user.email_address
    fill_in "Password", with: "password"
    click_on "Sign In"
    assert_current_path dashboard_path
  end

  teardown { Rails.cache = @original_cache }

  test "imports job leads from a CSV through every step" do
    csv = Tempfile.new([ "leads", ".csv" ])
    csv.write("Position,Employer,Job Link\nSystem Tester,Acme,https://acme.test/system\nNo Company,,https://acme.test/missing\n")
    csv.close

    visit new_account_import_url
    attach_file "file", csv.path, make_visible: true

    assert_text "Match Columns"
    click_on "Auto-Match Columns"
    assert_text "All required fields set"
    click_on "Continue to Review"

    assert_text "Needs Attention"
    fill_in "row_3_company", with: "Globex"
    click_on "Apply Fix"
    assert_text "Fixed and ready to import."
    click_on "Continue to Summary"

    assert_text "New Job Leads (2)"
    accept_confirm { click_on "Import 2 Job Leads" }

    assert_text "Imported 2 new job leads"
    assert @user.job_leads.exists?(title: "System Tester", company: "Acme")
    assert @user.job_leads.exists?(title: "No Company", company: "Globex")
  ensure
    csv&.unlink
  end
end
