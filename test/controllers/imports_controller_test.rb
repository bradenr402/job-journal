require "test_helper"

class ImportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @csv = "title,company,url\nDev,Acme,https://acme.test/import\n"

    # Drafts live in the cache, which is a null store in tests.
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Rails.cache = @original_cache }

  # Uploads, then presses Auto-Match (columns start unmatched) unless told not to.
  def upload(csv = @csv, filename: "leads.csv", auto_match: true)
    post account_imports_url, params: { file: Rack::Test::UploadedFile.new(StringIO.new(csv), "text/csv", original_filename: filename) }
    return unless auto_match && response.redirect?

    location = response.location
    patch account_import_url(draft_id), params: { page: "columns", auto_match: "1" }
    @last_upload_location = location
  end

  # The field chosen for a column (nil when it's set to "Don't import").
  def assert_mapped(index, field, message = nil)
    input = css_select("input[name='column_mapping[#{index}]']").first
    assert input, "no field input for column #{index}"
    field.nil? ? assert_nil(input["value"].presence, message) : assert_equal(field, input["value"], message)
  end

  def draft_id = (@last_upload_location || response.location)[%r{/account/import/([^/]+)/}, 1]

  test "columns start unmatched until Auto-Match is pressed" do
    upload(auto_match: false)
    id = draft_id
    get columns_account_import_url(id)
    assert_mapped 0, nil
    assert_select "#import-columns", /Still needed/

    patch account_import_url(id), params: { page: "columns", column_mapping: { "1" => "title" } }
    get columns_account_import_url(id)
    assert_select "button[name=auto_match][data-turbo-confirm]", 1, "Auto-Match confirms before replacing a hand-made choice"

    patch account_import_url(id), params: { page: "columns", auto_match: "1", column_mapping: { "1" => "title" } }
    get columns_account_import_url(id)
    assert_mapped 0, "title", "Auto-Match replaces hand-made choices"
    assert_mapped 2, "application_url"
    assert_select "#column_2_auto", /Auto-matched/
    assert_select "button[name=auto_match][data-turbo-confirm]", false, "no confirm when every choice came from Auto-Match"

    patch account_import_url(id), params: { page: "columns", clear_mapping: "1" }
    get columns_account_import_url(id)
    assert_mapped 0, nil
    assert_select "#column_0_auto", false
  end

  test "shows the upload form" do
    get new_account_import_url
    assert_response :success
    assert_select "input[type=file][name=file]"
  end

  test "uploading redirects to a columns page that survives a refresh" do
    upload
    assert_redirected_to %r{/account/import/.+/columns}
    id = draft_id

    2.times do
      get columns_account_import_url(id)
      assert_response :success
    end
    assert_mapped 0, "title"
    assert_select "#column_0_auto", /Auto-matched/
    assert_select "button[name=step][value=review]", /Continue/
  end

  test "rejects non-csv uploads" do
    upload(filename: "leads.txt")

    assert_response :unprocessable_content
    assert_select "#error_explanation", /\.csv/
  end

  test "continuing without required columns stays on the columns step" do
    upload
    id = draft_id
    patch account_import_url(id), params: { step: "review", page: "columns", mapping: { title: 0, company: "", application_url: "" } }

    assert_response :unprocessable_content
    assert_select "#error_explanation", /Company/
  end

  test "with nothing to review, continuing goes straight to a summary page that survives a refresh" do
    upload
    id = draft_id
    patch account_import_url(id), params: { step: "review", page: "columns" }
    assert_redirected_to summary_account_import_url(id)

    2.times do
      get summary_account_import_url(id)
      assert_response :success
    end
    assert_select "li", /Dev/
    assert_select "nav a[href=?]", columns_account_import_path(id)
    assert_select "nav a[href=?]", review_account_import_path(id)
  end

  test "rows needing attention go to review, and summary waits until they are resolved" do
    upload("title,company,url\nDev,,https://acme.test/import\n")
    id = draft_id
    patch account_import_url(id), params: { step: "review", page: "columns" }
    assert_redirected_to review_account_import_url(id)

    patch account_import_url(id), params: { step: "summary", page: "review" }
    assert_response :unprocessable_content
    assert_select "#error_explanation", /Fix or skip/

    get summary_account_import_url(id)
    assert_redirected_to review_account_import_url(id)

    patch account_import_url(id), params: { step: "summary", page: "review", rows: { "2" => { company: "Acme" } } }
    assert_redirected_to summary_account_import_url(id)
  end

  test "fixes are saved to the draft and refreshed with a turbo stream" do
    upload("title,company,url\nDev,,https://acme.test/import\n")
    id = draft_id

    assert_no_difference -> { @user.job_leads.count } do
      patch account_import_url(id), params: { page: "review", rows: { "2" => { company: "Acme" } } }, as: :turbo_stream
    end
    assert_response :success
    assert_match "import-body", response.body

    get summary_account_import_url(id)
    assert_select "li", /New/
  end

  test "imports and shows the batch" do
    upload
    id = draft_id

    assert_difference -> { @user.job_leads.count }, 1 do
      patch account_import_url(id), params: { step: "import", page: "review" }
    end

    assert_redirected_to job_leads_path(tags: "imported-#{Date.current.iso8601}", job_lead_state: "all")
    assert_match "Imported 1 new job lead", flash[:success]

    get review_account_import_url(id)
    assert_redirected_to new_account_import_url
  end

  test "a second click on Import goes to job leads instead of an expired error" do
    upload
    id = draft_id
    patch account_import_url(id), params: { step: "import", page: "review" }
    patch account_import_url(id), params: { step: "import", page: "review" }

    assert_redirected_to %r{/job_leads\?.*imported-}
  end

  test "changing a column drops fixes typed for that field" do
    upload("title,company,url,alt\nDev,,https://acme.test/import,Globex\n")
    id = draft_id
    patch account_import_url(id), params: { page: "review", rows: { "2" => { company: "Acme" } } }
    patch account_import_url(id), params: { page: "columns", mapping: { title: 0, company: 3, application_url: 2 } }

    get summary_account_import_url(id)
    assert_select "li", /Globex/
  end

  test "the summary page names the file and shows the batch tag" do
    upload
    id = draft_id
    get summary_account_import_url(id)

    assert_select "p", /leads\.csv/
    assert_select "#import-footer", /imported-/
  end

  test "existing leads with changes wait for Update Existing or Skip Row, one at a time or all at once" do
    lead = job_leads(:one)
    upload("title,company,url\nNew Title,#{lead.company},#{lead.application_url}\n")
    id = draft_id

    get review_account_import_url(id)
    assert_select "button[name='rows[2][duplicate]'][value=update]", /Update Existing/
    assert_select "button[name='rows[2][skip]'][value='1']", /Skip Row/

    patch account_import_url(id), params: { step: "summary", page: "review" }
    assert_response :unprocessable_content

    patch account_import_url(id), params: { step: "summary", page: "review", rows: { "2" => { duplicate: "update" } } }
    assert_redirected_to summary_account_import_url(id)

    patch account_import_url(id), params: { page: "review", bulk_duplicate: "skip" }
    get summary_account_import_url(id)
    assert_select "#import-footer", /Nothing to Import/
  end

  test "a fixed row stays on Review as Fixed, and any row can be skipped from Summary" do
    upload("title,company,url\nDev,,https://acme.test/import\nOps,Acme,https://acme.test/ops\n")
    id = draft_id
    patch account_import_url(id), params: { page: "review", rows: { "2" => { company: "Acme" } } }

    get review_account_import_url(id)
    assert_select "li#import-row-2", /Fixed/

    get summary_account_import_url(id)
    assert_select "li#import-row-3 button[name='rows[3][skip]']", /Skip/
    patch account_import_url(id), params: { page: "summary", rows: { "3" => { skip: "1" } } }
    get summary_account_import_url(id)
    assert_select "#import-footer", /Import 1 Job Lead/
  end

  test "including a row with problems from Summary goes back to Review" do
    upload("title,company,url\nDev,,https://acme.test/import\nOps,Acme,https://acme.test/ops\n")
    id = draft_id
    patch account_import_url(id), params: { page: "review", rows: { "2" => { skip: "1" } } }

    patch account_import_url(id), params: { page: "summary", rows: { "2" => { skip: "0" } } }, as: :turbo_stream
    assert_redirected_to review_account_import_url(id)
  end

  test "Skip All in Needs Attention skips every problem row" do
    upload("title,company,url\nDev,,https://acme.test/a\nOps,,https://acme.test/b\nQA,Acme,https://acme.test/c\n")
    id = draft_id
    get review_account_import_url(id)
    assert_select "button[name=bulk_skip]", /Skip All/

    patch account_import_url(id), params: { page: "review", bulk_skip: "problems" }
    get summary_account_import_url(id)
    assert_select "#import-footer", /Import 1 Job Lead/
  end

  test "columns are matched one per column, with a summary of what's still needed" do
    upload("Position,Employer,Link\nDev,Acme,https://acme.test/import\n")
    id = draft_id

    get columns_account_import_url(id)
    assert_mapped 1, "company"

    patch account_import_url(id), params: { step: "review", page: "columns", column_mapping: { "0" => "title", "1" => "company", "2" => "application_url" } }
    assert_redirected_to summary_account_import_url(id)

    patch account_import_url(id), params: { page: "columns", column_mapping: { "0" => "company", "1" => "", "2" => "application_url" } }
    get columns_account_import_url(id)
    assert_mapped 0, "company"
    assert_select "#import-columns", /Still needed: Job Title/
    assert_select "#column_0_auto", false, "a column changed by hand isn't marked auto-matched"
  end

  test "many unimported columns are collapsed" do
    upload("title,company,url,a,b,c,d,e\nDev,Acme,https://acme.test/import,1,2,3,4,5\n")
    get columns_account_import_url(draft_id)

    assert_select "details summary", /Show 5 Not-Imported Columns/
    assert_select "details[open]", false

    patch account_import_url(draft_id), params: { page: "columns", show_unmatched: "1" }
    get columns_account_import_url(draft_id)
    assert_select "details[open]"
  end

  test "breadcrumbs link ahead only once earlier steps are complete" do
    upload("title,company,url\nDev,,https://acme.test/import\n", auto_match: false)
    id = draft_id
    get columns_account_import_url(id)
    assert_select "nav a[href=?]", review_account_import_path(id), false

    patch account_import_url(id), params: { page: "columns", auto_match: "1" }
    get columns_account_import_url(id)
    assert_select "nav a[href=?]", review_account_import_path(id)
    assert_select "nav a[href=?]", summary_account_import_path(id), false

    patch account_import_url(id), params: { page: "review", rows: { "2" => { company: "Acme" } } }
    get columns_account_import_url(id)
    assert_select "nav a[href=?]", summary_account_import_path(id)
  end

  test "only real rows, known fields, and real columns are saved to the draft" do
    upload
    id = draft_id
    patch account_import_url(id), params: { page: "review", rows: { "2" => { company: "Acme", admin: "1" }, "999" => { company: "X" } } }
    patch account_import_url(id), params: { page: "columns", mapping: { title: 0, company: 1, application_url: 2, bogus: 1, location: 99 } }

    draft = ImportDraft.find(user: @user, id:)
    assert_equal({ "company" => "Acme" }, draft[:overrides]["2"])
    assert_nil draft[:overrides]["999"]
    assert_equal %w[application_url company title], draft[:mapping].keys.sort
  end

  test "save errors quoted in the flash are escaped" do
    row = JobLeadImport::Row.new(line: 3, errors: [ "Status “<script>alert(1)</script>” isn’t recognized." ])
    result = JobLeadImport::Result.new(failed_rows: [ row ])

    summary = ImportsController.new.send(:failure_summary, result)
    assert_includes summary, "&lt;script&gt;"
    assert_not_includes summary, "<script>"
  end

  test "an expired or unknown draft starts over" do
    get columns_account_import_url("missing")
    assert_redirected_to new_account_import_url
  end
end
