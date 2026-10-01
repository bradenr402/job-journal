require "test_helper"

class JobLeadImportTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  def import(csv, **options) = JobLeadImport.new(user: @user, csv:, **options)

  test "guesses columns from messy headers" do
    importer = import("Job Title,Company Name,Job URL,Date Applied,Labels\nDev,Acme,https://acme.test/1,2026-01-05,remote\n")

    assert_equal({ "title" => 0, "company" => 1, "application_url" => 2, "applied_at" => 3, "tags" => 4 }, importer.mapping)
  end

  test "imports valid rows and tags the batch" do
    csv = "title,company,url,status,applied,tags\nDev,Acme,https://acme.test/1,applied,2026-01-05,Remote; Rails\n"

    result = nil
    assert_difference -> { @user.job_leads.count }, 1 do
      result = import(csv).import!
    end

    lead = @user.job_leads.find_by(application_url: "https://acme.test/1")
    assert_equal "applied", lead.status
    assert_equal [ "rails", "remote", result.batch_tag ].sort, lead.tags.pluck(:name).sort
    assert lead.created_at <= lead.applied_at
  end

  test "flags bad rows without importing them" do
    csv = <<~CSV
      title,company,url,applied
      Dev,,https://acme.test/2,2026-01-05
      Dev,Acme,https://acme.test/3,not a date
      Dev,Acme,https://acme.test/4,
      Dev,Acme,https://acme.test/4,
    CSV
    importer = import(csv)

    assert_equal({ create: 1, update: 0, skip: 0, fix: 3 }, importer.summary)
    assert_match "Company is missing", importer.rows[0].errors.first
    assert_match "isn’t a date", importer.rows[1].errors.first
    assert_match "Same application URL as an earlier row", importer.rows[3].errors.first
  end

  test "skips existing job leads by default" do
    existing = job_leads(:one)
    importer = import("title,company,url\nNew Title,Acme,#{existing.application_url}\n")

    # A differing existing lead waits for a decision before anything can be imported.
    assert_equal :fix, importer.rows.first.action
    assert_raises(JobLeadImport::Error) { importer.import! }
    assert_equal existing.title, existing.reload.title
  end

  test "can update existing job leads instead" do
    existing = job_leads(:one)
    original_company = existing.company
    importer = import("title,company,url,location\nNew Title,,#{existing.application_url},Remote\n", on_duplicate: "update")

    # A blank company in update mode is still required by the import.
    assert_equal :fix, importer.rows.first.action

    importer = import("title,company,url,location\nNew Title,#{original_company},#{existing.application_url},Remote\n", on_duplicate: "update")
    assert_equal :update, importer.rows.first.action

    result = importer.import!
    assert_equal 1, result.updated
    assert_equal [ "New Title", "Remote" ], existing.reload.values_at(:title, :location)
  end

  test "values typed in the preview fill in missing fields" do
    csv = "title,company,url,applied\nDev,,https://acme.test/7,someday\n"

    row = import(csv).rows.first
    assert_equal %w[company applied_at], row.fixable

    row = import(csv, overrides: { "2" => { "company" => "Acme", "applied_at" => "2026-01-05" } }).rows.first
    assert row.valid?
    assert_equal :create, row.action
    assert_equal "Acme", row.job_lead.company
  end

  test "a blank fix input keeps the row's original problem" do
    csv = "title,company,url,applied\nDev,Acme,https://acme.test/8,not a date\n"
    row = import(csv, overrides: { "2" => { "applied_at" => "" } }).rows.first

    assert_not row.valid?
    assert_match "isn’t a date", row.errors.first
  end

  test "duplicates can be updated or skipped row by row" do
    existing = job_leads(:one)
    csv = "title,company,url\nNew Title,#{existing.company},#{existing.application_url}\n"

    assert_equal :fix, import(csv).rows.first.action
    assert_equal existing, import(csv).rows.first.duplicate
    assert_equal :skip, import(csv, overrides: { "2" => { "skip" => "1" } }).rows.first.action
    assert_equal :update, import(csv, overrides: { "2" => { "duplicate" => "update" } }).rows.first.action
  end

  test "detects day-first dates" do
    importer = import("title,company,url,applied\nA,B,https://acme.test/d1,03/04/2026\nA,B,https://acme.test/d2,25/04/2026\n")

    assert_equal "dmy", importer.date_format
    assert_equal Date.new(2026, 4, 3), importer.rows.first.job_lead.applied_at.to_date
  end

  test "defaults ambiguous dates to month-first and can be switched" do
    csv = "title,company,url,applied\nA,B,https://acme.test/d3,03/04/2026\n"

    assert_equal "03/04/2026", import(csv).ambiguous_date_example
    assert_equal Date.new(2026, 3, 4), import(csv).rows.first.job_lead.applied_at.to_date
    assert_equal Date.new(2026, 4, 3), import(csv, date_format: "dmy").rows.first.job_lead.applied_at.to_date
  end

  test "shows sample values for a column" do
    assert_equal %w[Acme Globex], import("company\nAcme\n\"\"\nGlobex\nAcme\n").samples_for(0)
  end

  test "describes what updating an existing lead would change" do
    existing = job_leads(:one)
    row = import("title,company,url\nNew Title,#{existing.company},#{existing.application_url}\n").rows.first

    assert_equal({ "title" => [ existing.title, "New Title" ] }, row.changes)
  end

  test "the change list survives choosing Update Existing" do
    existing = job_leads(:one)
    csv = "title,company,url\nNew Title,#{existing.company},#{existing.application_url}\n"
    row = import(csv, overrides: { "2" => { "duplicate" => "update" } }).rows.first

    assert_equal :update, row.action
    assert_equal({ "title" => [ existing.title, "New Title" ] }, row.changes)
  end

  test "bulk update applies to rows without their own choice" do
    existing = job_leads(:one)
    csv = "title,company,url\nNew Title,#{existing.company},#{existing.application_url}\n"

    assert_equal :update, import(csv, on_duplicate: "update").rows.first.action
    assert_equal :skip, import(csv, on_duplicate: "update", overrides: { "2" => { "duplicate" => "skip" } }).rows.first.action
  end

  test "previewing does not write to the database" do
    existing = job_leads(:one)

    assert_no_changes -> { existing.reload.updated_at } do
      import("title,company,url,rejected\nX,Y,#{existing.application_url},2026-01-05\n", on_duplicate: "update").rows
    end
  end

  test "an offer status without an amount needs an amount or an explicit choice" do
    csv = "title,company,url,status\nDev,Acme,https://acme.test/5,offer\n"
    row = import(csv).rows.first

    assert_equal :fix, row.action
    assert row.offer_choice_needed
    assert_equal [ "offer_amount" ], row.fixable

    assert_equal "offer", import(csv, overrides: { "2" => { "offer_amount" => "90000" } }).rows.first.job_lead.status
    assert_equal "applied", import(csv, overrides: { "2" => { "offer_choice" => "applied" } }).rows.first.job_lead.status
  end

  test "rows can be skipped by hand, and import waits until every row is fixed or skipped" do
    csv = "title,company,url\nDev,,https://acme.test/9\n"

    assert_raises(JobLeadImport::Error) { import(csv).import! }

    row = import(csv, overrides: { "2" => { "skip" => "1" } }).rows.first
    assert_equal :skip, row.action
    error = assert_raises(JobLeadImport::Error) { import(csv, overrides: { "2" => { "skip" => "1" } }).import! }
    assert_match "nothing to import", error.message
  end

  test "errors from a failed save keep the row in Needs Attention until it changes" do
    csv = "title,company,url\nDev,Acme,https://acme.test/11\n"
    row = import(csv, save_errors: { "2" => [ "Something went wrong" ] }).rows.first

    assert_equal :fix, row.action
    assert_includes row.errors, "Something went wrong"
    assert_equal :skip, import(csv, save_errors: { "2" => [ "x" ] }, overrides: { "2" => { "skip" => "1" } }).rows.first.action
  end

  test "a column can feed only one field" do
    importer = import("a,b,c\nx,y,https://acme.test/10\n", mapping: { "title" => "0", "company" => "0", "application_url" => "2" })

    assert_equal({ "title" => 0, "application_url" => 2 }, importer.mapping)
  end

  test "parses offer amounts" do
    row = import("title,company,url,status,offer amount\nDev,Acme,https://acme.test/6,offer,\"$105,000\"\n").rows.first

    assert_equal 105_000, row.job_lead.offer_amount
    assert_equal "offer", row.job_lead.status
  end

  test "round-trips a JobJournal export" do
    csv = AccountExport.new(@user).to_csv("job_leads")
    importer = import(csv)

    assert_empty importer.missing_required_fields
    assert importer.rows.all? { it.action == :skip }, "every exported lead already exists"
  end

  test "rejects unreadable files" do
    assert_raises(JobLeadImport::Error) { import("") }
    assert_raises(JobLeadImport::Error) { import("title\n") }
    assert_raises(JobLeadImport::Error) { import("a,\"b\n1,2") }
    assert_raises(JobLeadImport::Error) { import("title\n" + "x\n" * (JobLeadImport::MAX_ROWS + 1)) }
  end

  test "requires the title, company, and url columns" do
    importer = import("name\nDev\n")

    assert_equal %w[title company application_url], importer.missing_required_fields
    assert_raises(JobLeadImport::Error) { importer.import! }
  end
end
