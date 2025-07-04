class JobLead < ApplicationRecord
  # Constants

  # Statuses ranked by progression/quality.
  STATUS_QUALITY = {
    lead:         1,
    applied:      2,
    phone_screen: 3,
    interview:    5,
    offer:        8,
    accepted:    13,
    rejected:     0
  }.freeze

  # Associations
  belongs_to :user
  has_many :notes, as: :notable, dependent: :destroy
  has_many :interviews, dependent: :destroy
  # has_many :applications, dependent: :destroy
  # has_many :job_lead_tags, dependent: :destroy
  # has_many :tags, through: :job_lead_tags

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

  # scope :recently_applied, -> { joins(:applications).where('applications.applied_on > ?', 30.days.ago) }
  # scope :interviewing_this_week, -> { joins(:interviews).where(interviews: { date: Time.current.all_week }) }

  # Instance Methods
  def active? = archived_at.nil?
  def archived? = archived_at.present?

  def archive! = update(archived_at: Time.current)
  def unarchive! = update(archived_at: nil)

  # def all_notes = Note.where(notable: [ self ] + interviews)

  # Class Methods
  def self.status_quality(status)
    STATUS_QUALITY[status.to_sym]
  end

  def self.top_sources_by_quality(limit = 4)
    leads = where.not(source: [ nil, '' ])

    ranked = leads.group_by { it.source.downcase }.map do |_, group|
      most_common_casing = group.group_by(&:source).max_by { |_, leads| leads.size }.first
      count = group.size

      highest_quality = group.map { |lead| status_quality(lead.status) }.max

      latest_created_at = group.max_by(&:created_at)&.created_at

      interview_count = group.count { |lead| status_quality(lead.status) >= STATUS_QUALITY[:interview] }
      offer_count     = group.count { |lead| status_quality(lead.status) >= STATUS_QUALITY[:offer] }

      [
        most_common_casing,
        count,
        highest_quality,
        latest_created_at,
        interview_count,
        offer_count
      ]
    end

    filtered = ranked.reject { |_, _, _, _, interview_count, offer_count| interview_count.zero? && offer_count.zero? }

    sorted = filtered.sort_by do |_, count, highest_quality, latest_created_at, _, _|
      [ -highest_quality, -count, -latest_created_at.to_i ]
    end

    # Return a hash: { 'Source Name' => { count:, interview_count:, offer_count: }, ... }
    sorted.first(limit).to_h do |source, count, _, _, interview_count, offer_count|
      [ source, { count:, interview_count:, offer_count: } ]
    end
  end

  private

  def update_status
    if offer_amount_changed? && offer_amount.present?
      self.status = :offer
    end
  end
end
