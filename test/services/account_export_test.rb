require "test_helper"

class AccountExportTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @export = AccountExport.new(@user)
  end

  test "json includes only the user's own records" do
    data = JSON.parse(@export.to_json)

    assert_equal @user.email_address, data.dig("account", "email_address")
    assert_equal @user.job_leads.count, data["job_leads"].size
    assert_equal @user.job_leads.ids.sort, data["job_leads"].map { it["id"] }.sort
  end

  test "json nests interviews under their job lead" do
    data = JSON.parse(@export.to_json)

    assert_equal @user.interviews.count, data["job_leads"].sum { it["interviews"].size }
  end

  test "json nests notes under the job lead or interview they belong to" do
    data = JSON.parse(@export.to_json)
    nested = data["job_leads"].sum { it["notes"].size + it["interviews"].sum { |interview| interview["notes"].size } }

    assert_nil data["notes"]
    assert_equal @user.notes.count, nested
  end

  test "csv has a header row and one row per record" do
    AccountExport::DATASETS.each do |dataset|
      rows = CSV.parse(@export.to_csv(dataset), headers: true)
      assert_equal @user.public_send(dataset).count, rows.size, dataset
    end
  end

  test "job leads csv joins tags into one cell" do
    rows = CSV.parse(@export.to_csv("job_leads"), headers: true)
    lead = job_leads(:one)

    assert_equal lead.tags.map(&:name).sort.join(", "), rows.find { it["id"] == lead.id.to_s }["tags"]
  end

  test "csv escapes cells that spreadsheets would run as formulas" do
    job_leads(:one).update_columns(title: "=HYPERLINK(\"x\")")
    rows = CSV.parse(@export.to_csv("job_leads"), headers: true)

    assert_equal "'=HYPERLINK(\"x\")", rows.find { it["id"] == job_leads(:one).id.to_s }["title"]
  end

  test "rejects unknown datasets" do
    assert_raises(ArgumentError) { @export.to_csv("sessions") }
  end
end
