class User < ApplicationRecord
  # Constants
  DEFAULT_SETTINGS = {
    weekly_application_goal: 10,

    job_leads_display: 'grid',
    interviews_display: 'grid',
    notes_display: 'grid',

    auto_archive_rejected_leads_enabled: true,

    auto_archive_inactive_leads_enabled: true,
    auto_archive_inactive_lead_days: 28,

    auto_archive_stale_leads_enabled: true,
    job_lead_stale_after_days: 7,
    auto_archive_stale_lead_days: 21,

    application_follow_up_days: 7,
    interview_follow_up_days: 2,
    suggest_follow_up_days: 3
  }.with_indifferent_access.freeze

  # Authentication
  has_secure_password

  # Serialize settings as a Hash
  serialize :settings, coder: JSON

  # Dynamically define accessors for all DEFAULT_SETTINGS keys
  store_accessor :settings, *DEFAULT_SETTINGS.keys

  # Associations
  has_many :sessions, dependent: :destroy
  has_many :job_leads, dependent: :destroy
  has_many :notes, dependent: :destroy
  has_many :interviews, through: :job_leads
  has_many :tags, dependent: :destroy

  # Normalizations
  normalizes :email_address, with: -> { _1.strip.downcase }
  normalizes :name, with: -> { _1.strip }

  # Validations
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, on: :create
  validates :password, presence: true, on: :update, if: -> { password.present? || password_confirmation.present? }

  # Aliases
  alias_attribute :email, :email_address

  # Instance Methods
  def settings = super.with_indifferent_access

  def get_setting(key) = settings.key?(key) ? settings[key] : DEFAULT_SETTINGS[key]

  def all_settings = DEFAULT_SETTINGS.merge(settings)

  def set_setting(key, value)
    self.settings = settings.merge(key => value)
    save(validate: false)
  end

  def reset_all_settings
    self.settings = {}
    save(validate: false)
  end

  def weekly_application_goal_progress
    this_week = Time.current.all_week
    count = job_leads.where(applied_at: this_week).count.to_f
    goal = get_setting(:weekly_application_goal).to_f
    return 0 unless goal.positive?

    ((count / goal) * 100).clamp(0, Float::INFINITY).round
  end
end
