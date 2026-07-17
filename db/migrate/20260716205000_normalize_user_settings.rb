class NormalizeUserSettings < ActiveRecord::Migration[8.0]
  LEGACY_SETTING_PATHS = {
    weekly_application_goal: %i[goals weekly_applications],

    job_leads_filter:  %i[filters job_leads],
    interviews_filter: %i[filters interviews],
    notes_filter:      %i[filters notes],

    job_leads_display:  %i[layouts job_leads],
    interviews_display: %i[layouts interviews],
    notes_display:      %i[layouts notes],

    auto_archive_rejected_leads_enabled: %i[archiving rejected enabled],

    auto_archive_inactive_leads_enabled: %i[archiving inactive enabled],
    auto_archive_inactive_lead_days:     %i[archiving inactive after_days],

    auto_archive_stale_leads_enabled: %i[archiving stale enabled],
    job_lead_stale_after_days:        %i[archiving stale mark_after_days],
    auto_archive_stale_lead_days:     %i[archiving stale archive_after_days],

    application_follow_up_days: %i[follow_ups application_days],
    interview_follow_up_days:   %i[follow_ups interview_days],
    suggest_follow_up_days:     %i[follow_ups suggestion_days]
  }.with_indifferent_access.freeze

  def up
    User.transaction do
      User.find_each do |user|
        migrated_settings = migrate_settings(user.settings)
        sanitized_settings = User::Settings.sanitize(migrated_settings)

        user.update_columns(settings: sanitized_settings)
      end
    end
  end

  def down
    User.transaction do
      User.find_each do |user|
        legacy_settings = revert_settings(user.settings)
        user.update_columns(settings: legacy_settings)
      end
    end
  end

  private

  def migrate_settings(settings)
    migrated_settings = {}

    LEGACY_SETTING_PATHS.each do |legacy_key, path|
      next unless settings.key?(legacy_key)

      legacy_value = settings[legacy_key]

      nested_setting = legacy_value
      path.reverse_each do |key|
        nested_setting = { key => nested_setting }
      end

      migrated_settings.deep_merge!(nested_setting)
    end

    migrated_settings
  end

  def revert_settings(settings)
    reverted_settings = {}

    LEGACY_SETTING_PATHS.each do |legacy_key, path|
      legacy_value = settings.dig(*path)
      next if legacy_value.nil?

      reverted_settings[legacy_key] = legacy_value
    end

    reverted_settings
  end
end
