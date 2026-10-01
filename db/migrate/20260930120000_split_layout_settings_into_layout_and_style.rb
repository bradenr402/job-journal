class SplitLayoutSettingsIntoLayoutAndStyle < ActiveRecord::Migration[8.0]
  SECTIONS = %w[job_leads interviews notes].freeze

  def up
    User.transaction do
      User.find_each do |user|
        settings = user.settings
        next unless settings.key?(:layouts)

        user.update_columns(settings: migrate_settings(settings))
      end
    end
  end

  def down
    User.transaction do
      User.find_each do |user|
        settings = user.settings
        next unless settings.key?(:appearance)

        user.update_columns(settings: revert_settings(settings))
      end
    end
  end

  private

  def migrate_settings(settings)
    layouts = settings[:layouts]

    appearance = {
      layout: layouts[:job_leads].in?(%w[list minimal]) ? "list" : "grid",
      style: layouts.values_at(*SECTIONS).include?("minimal") ? "minimal" : "cards"
    }

    settings.except(:layouts).merge(appearance:)
  end

  def revert_settings(settings)
    appearance = settings[:appearance]

    layout =
      if appearance[:style] == "minimal"
        "minimal"
      else
        appearance[:layout] == "list" ? "list" : "grid"
      end

    settings.except(:appearance).merge(layouts: SECTIONS.index_with { layout })
  end
end
