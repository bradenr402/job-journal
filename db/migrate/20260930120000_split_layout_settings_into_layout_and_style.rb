# Replaces the per-section `layouts` settings (grid/list/minimal) with global
# `appearance.layout` (grid/list) and `appearance.style` (cards/minimal).
#
# * Layout comes from the Job Leads section, with Minimal becoming List.
# * Style is Minimal if any section was Minimal, otherwise Cards.
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
    layouts = settings[:layouts].is_a?(Hash) ? settings[:layouts] : {}

    appearance = {
      layout: layouts[:job_leads].in?(%w[list minimal]) ? "list" : "grid",
      style: layouts.values_at(*SECTIONS).include?("minimal") ? "minimal" : "cards"
    }

    settings.except(:layouts).merge(appearance:)
  end

  # Lossy: Grid + Minimal has no legacy equivalent and becomes Minimal.
  def revert_settings(settings)
    appearance = settings[:appearance].is_a?(Hash) ? settings[:appearance] : {}

    layout =
      if appearance[:style] == "minimal"
        "minimal"
      else
        appearance[:layout] == "list" ? "list" : "grid"
      end

    settings.except(:appearance).merge(layouts: SECTIONS.index_with { layout })
  end
end
