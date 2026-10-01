require "test_helper"
require Dir.glob(Rails.root.join("db/migrate/*_split_layout_settings_into_layout_and_style.rb")).sole

class SplitLayoutSettingsIntoLayoutAndStyleTest < ActiveSupport::TestCase
  setup do
    @migration_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false

    @migration = SplitLayoutSettingsIntoLayoutAndStyle.new
    @user = users(:one)
  end

  teardown do
    ActiveRecord::Migration.verbose = @migration_verbose
  end

  def migrate(layouts)
    @user.update_columns(settings: { goals: { weekly_applications: 5 }, layouts: })
    @migration.migrate(:up)
    @user.reload.settings
  end

  test "maps grid to grid + cards" do
    assert_equal({ "layout" => "grid", "style" => "cards" }, migrate(job_leads: "grid")[:appearance])
  end

  test "maps list to list + cards" do
    assert_equal({ "layout" => "list", "style" => "cards" }, migrate(job_leads: "list")[:appearance])
  end

  test "maps minimal to list + minimal" do
    assert_equal({ "layout" => "list", "style" => "minimal" }, migrate(job_leads: "minimal")[:appearance])
  end

  test "uses the job leads layout and minimal if any section was minimal" do
    settings = migrate(job_leads: "grid", interviews: "list", notes: "minimal")

    assert_equal({ "layout" => "grid", "style" => "minimal" }, settings[:appearance])
  end

  test "defaults to grid when job leads had no layout" do
    assert_equal({ "layout" => "grid", "style" => "cards" }, migrate(notes: "list")[:appearance])
  end

  test "removes legacy layouts and keeps other settings" do
    settings = migrate(job_leads: "list")

    assert_not settings.key?(:layouts)
    assert_equal 5, settings.dig(:goals, :weekly_applications)
    assert_equal "list", @user.get_setting(:appearance, :layout)
  end

  test "leaves users without legacy layouts untouched" do
    @user.update_columns(settings: { goals: { weekly_applications: 5 } })
    @migration.migrate(:up)

    assert_equal({ "goals" => { "weekly_applications" => 5 } }, @user.reload.settings)
  end

  test "reverts to per-section layouts" do
    migrate(job_leads: "grid", notes: "minimal")
    @migration.migrate(:down)
    settings = @user.reload.settings

    assert_not settings.key?(:appearance)
    assert_equal({ "job_leads" => "minimal", "interviews" => "minimal", "notes" => "minimal" }, settings[:layouts])
  end
end
