require "test_helper"
require Dir.glob(Rails.root.join("db/migrate/*_normalize_user_settings.rb")).sole

class NormalizeUserSettingsTest < ActiveSupport::TestCase
  setup do
    @migration_verbose = ActiveRecord::Migration.verbose

    ActiveRecord::Migration.verbose = false
    @migration = NormalizeUserSettings.new
    @migration.migrate(:down)
  end

  teardown do
    @migration.migrate(:down)
    ActiveRecord::Migration.verbose = @migration_verbose

    ActiveRecord::Base.clear_cache!
  end

  test "migrates valid legacy settings to the correct structural keys" do
    legacy_settings = {
      weekly_application_goal: 12,
      job_leads_filter: "active",
      notes_display: "minimal",
      auto_archive_rejected_leads_enabled: false,
      auto_archive_inactive_lead_days: 45
    }.with_indifferent_access

    migrated = @migration.send(:migrate_settings, legacy_settings)
    sanitized = User::Settings.sanitize(migrated)

    assert_equal 12, sanitized.dig(:goals, :weekly_applications)
    assert_equal "active", sanitized.dig(:filters, :job_leads)
    assert_equal "minimal", sanitized.dig(:layouts, :notes)
    assert_equal false, sanitized.dig(:archiving, :rejected, :enabled)
    assert_equal 45, sanitized.dig(:archiving, :inactive, :after_days)
  end

  test "migrates raw keys for mixed payloads before validation sanitization" do
    mixed_settings = {
      weekly_application_goal: -1,
      job_leads_filter: "bogus",
      notes_filter: "active",
      application_follow_up_days: 5
    }.with_indifferent_access

    migrated = @migration.send(:migrate_settings, mixed_settings)

    assert_equal(-1, migrated.dig(:goals, :weekly_applications))
    assert_equal "bogus", migrated.dig(:filters, :job_leads)
  end

  test "strips invalid keys and accepts valid fields during mixed payload sanitization" do
    mixed_settings = {
      weekly_application_goal: -1,
      job_leads_filter: "bogus",
      notes_filter: "active",
      application_follow_up_days: 5
    }.with_indifferent_access

    migrated = @migration.send(:migrate_settings, mixed_settings)
    sanitized = User::Settings.sanitize(migrated)

    assert_nil sanitized.dig(:goals, :weekly_applications)
    assert_nil sanitized.dig(:filters, :job_leads)
    assert_equal "active", sanitized.dig(:filters, :notes)
    assert_equal 5, sanitized.dig(:follow_ups, :application_days)
  end

  test "migrates legacy settings up to nested paths and back down" do
    user = users(:one)
    user.update_columns(settings: {
      weekly_application_goal: 12,
      job_leads_filter: "active",
      auto_archive_rejected_leads_enabled: false,
      notes_filter: "bogus"
    })

    @migration.migrate(:up)
    user.reload

    assert_equal 12, user.settings.dig(:goals, :weekly_applications)
    assert_equal "active", user.settings.dig(:filters, :job_leads)
    assert_equal false, user.settings.dig(:archiving, :rejected, :enabled)
    assert_nil user.settings.dig(:filters, :notes)

    @migration.migrate(:down)
    user.reload

    assert_equal 12, user.settings[:weekly_application_goal]
    assert_equal "active", user.settings[:job_leads_filter]
    assert_equal false, user.settings[:auto_archive_rejected_leads_enabled]
    assert_nil user.settings[:notes_filter]
  end
end
