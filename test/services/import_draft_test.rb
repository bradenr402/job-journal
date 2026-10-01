require "test_helper"

class ImportDraftTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Rails.cache = @original_cache }

  test "saves and finds a draft" do
    draft = ImportDraft.create(user: @user, csv: "title\nDev\n", mapping: { "title" => 0 })

    found = ImportDraft.find(user: @user, id: draft.id)
    assert_equal "title\nDev\n", found[:csv]
    assert_equal({ "title" => 0 }, found[:mapping])
  end

  test "drafts are private to their user" do
    draft = ImportDraft.create(user: @user, csv: "title\nDev\n")

    assert_raises(ImportDraft::NotFound) { ImportDraft.find(user: users(:two), id: draft.id) }
  end

  test "updates merge into the saved attributes" do
    draft = ImportDraft.create(user: @user, csv: "title\nDev\n", mapping: { "title" => 0 })
    draft.update(date_format: "dmy")

    found = ImportDraft.find(user: @user, id: draft.id)
    assert_equal "dmy", found[:date_format]
    assert_equal({ "title" => 0 }, found[:mapping])
  end

  test "destroy removes the draft" do
    draft = ImportDraft.create(user: @user, csv: "title\nDev\n")
    draft.destroy

    assert_raises(ImportDraft::NotFound) { ImportDraft.find(user: @user, id: draft.id) }
  end

  test "builds an import from its attributes" do
    draft = ImportDraft.create(user: @user, csv: "title,company,url\nDev,Acme,https://acme.test/draft\n",
                               mapping: { "title" => 0, "company" => 1, "application_url" => 2 }, overrides: {})

    import = draft.import
    assert_empty import.missing_required_fields
    assert_equal 1, import.row_count
  end
end
