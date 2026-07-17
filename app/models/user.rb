class User < ApplicationRecord
  include Settings

  # Authentication
  has_secure_password

  # Associations
  has_many :sessions, dependent: :destroy
  has_many :job_leads, dependent: :destroy
  has_many :notes, dependent: :destroy
  has_many :interviews, through: :job_leads
  has_many :tags, dependent: :destroy

  # Normalizations
  normalizes :email_address, with: -> { it.strip.downcase }
  normalizes :name, with: -> { it.strip }

  # Validations
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, on: :create
  validates :password, presence: true, on: :update, if: -> { password.present? || password_confirmation.present? }

  # Aliases
  alias_attribute :email, :email_address

  def weekly_application_goal_progress
    this_week = Time.current.all_week
    count = job_leads.where(applied_at: this_week).count.to_f
    goal = get_setting(:goals, :weekly_applications).to_f
    return 0 unless goal.positive?

    ((count / goal) * 100).clamp(0, Float::INFINITY).round
  end
end
