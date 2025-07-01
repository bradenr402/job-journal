class JobLead < ApplicationRecord
  # Associations
  belongs_to :user
  # has_many :applications, dependent: :destroy
  # has_many :notes, as: :notable, dependent: :destroy
  # has_many :job_lead_tags, dependent: :destroy
  # has_many :tags, through: :job_lead_tags
  # has_many :interviews, dependent: :destroy

  # Enums
  enum :status, {
    lead: 0,
    applied: 1,
    phone_screen: 2,
    interview: 3,
    offer: 4,
    rejected: 5,
    accepted: 6
  }

  # Validations
  validates :company, presence: true
  validates :title, presence: true
  validates :application_url, presence: true, uniqueness: true, format: URI::DEFAULT_PARSER.make_regexp(%w[http https])
  validates :offer_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :status, presence: true, inclusion: { in: statuses.keys }

  # Callbacks
  before_validation :update_status, on: :update

  # Scopes
  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  scope :recently_applied, -> {
    joins(:applications).where('applications.applied_on > ?', 30.days.ago)
  }

  scope :interviewing_this_week, -> {
    joins(:interviews).where(interviews: { date: Time.current.all_week })
  }

  # Instance Methods
  def active? = archived_at.nil?
  def archived? = archived_at.present?

  # def all_notes = Note.where(notable: [ self ] + interviews)

  private

  def update_status
    if offer_amount_changed? && offer_amount.present?
      self.status = :offer
    end
  end
end
