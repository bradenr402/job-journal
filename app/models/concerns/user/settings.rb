module User::Settings
  extend ActiveSupport::Concern

  SCHEMA = {
    goals: {
      weekly_applications: { default: 10, allowed: 0.. }
    },

    filters: {
      job_leads: { default: "all", allowed: %w[all active archived] },
      interviews: { default: "all", allowed: %w[all upcoming completed] },
      notes: { default: "all", allowed: %w[all active archived] }
    },

    layouts: {
      job_leads: { default: "grid", allowed: %w[grid list minimal] },
      interviews: { default: "grid", allowed: %w[grid list minimal] },
      notes: { default: "grid", allowed: %w[grid list minimal] }
    },

    archiving: {
      rejected: {
        enabled: { default: true, allowed: [ true, false ] }
      },
      inactive: {
        enabled: { default: true, allowed: [ true, false ] },
        after_days: { default: 28, allowed: 1.. }
      },
      stale: {
        enabled: { default: true, allowed: [ true, false ] },
        mark_after_days: { default: 7, allowed: 1.. },
        archive_after_days: { default: 21, allowed: 1.. }
      }
    },

    follow_ups: {
      application_days: { default: 7, allowed: 1.. },
      interview_days: { default: 2, allowed: 1.. },
      suggestion_days: { default: 3, allowed: 1.. }
    }
  }.with_indifferent_access.freeze

  def self.defaults(schema)
    schema.transform_values do |value|
      value.key?(:default) ? value[:default] : defaults(value)
    end
  end

  DEFAULT_SETTINGS = defaults(SCHEMA).freeze

  included do
    serialize :settings, coder: JSON
    before_save :normalize_settings_payload
  end

  def self.valid_value?(value, path)
    allowed = SCHEMA.dig(*path, :allowed)
    return false if allowed.nil?

    case allowed
    when Range
      value.is_a?(Integer) && allowed.cover?(value)
    else
      value.in?(allowed)
    end
  end

  def self.sanitize(input, schema = SCHEMA, path = [])
    return {}.with_indifferent_access unless input.is_a?(Hash)

    input.each_with_object({}.with_indifferent_access) do |(key, value), result|
      entry = schema[key]
      next if entry.nil?

      if entry.key?(:default)
        result[key] = value if valid_value?(value, path + [ key ])
      else
        nested = sanitize(value, entry, path + [ key ])
        result[key] = nested if nested.any?
      end
    end
  end

  def settings = super.with_indifferent_access

  def get_setting(*path) = all_settings.dig(*path)

  def all_settings = DEFAULT_SETTINGS.deep_merge(normalized_settings)

  def update_settings(new_settings)
    self.settings = normalized_settings.deep_merge(User::Settings.sanitize(new_settings))
    save(validate: false)
  end

  def reset_all_settings
    self.settings = {}
    save(validate: false)
  end

  private

  def normalize_settings_payload
    self.settings = normalized_settings
  end

  def normalized_settings = User::Settings.sanitize(settings)
end
