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

  # Attributes
  attr_reader :pending_tag_names

  # Associations
  belongs_to :user
  has_many :notes, as: :notable, dependent: :destroy
  has_many :interviews, dependent: :destroy
  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings

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
  after_save_commit :assign_tags

  # Scopes
  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :with_tag, ->(tag_name) { joins(:tags).where(tags: { name: tag_name.downcase }) }
  scope :with_tags, ->(tag_names) {
    tag_names = tag_names.map(&:downcase)
    return none if tag_names.empty?

    matching_ids = joins(:tags)
      .where('LOWER(tags.name) IN (?)', tag_names)
      .group('job_leads.id')
      .having('COUNT(DISTINCT tags.id) = ?', tag_names.size)
      .pluck(:id)

    where(id: matching_ids)
  }
  scope :with_any_tags, ->(tag_names) {
    tag_names = tag_names.map(&:downcase)
    return none if tag_names.empty?

    joins(:tags)
      .where('LOWER(tags.name) IN (?)', tag_names)
      .distinct
  }

  # Instance Methods
  def active? = archived_at.nil?
  def archived? = archived_at.present?

  def archive! = update(archived_at: Time.current)
  def unarchive! = update(archived_at: nil)

  def tag_list = tags.pluck(:name).join(', ')

  def tag_list=(names)
    @pending_tag_names = names.to_s.split(',').map { it.strip.downcase }.reject(&:blank?).uniq
  end

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

    if status_changed? && rejected? && !archived?
      self.archive!
    end
  end

  def assign_tags
    return if @pending_tag_names.blank?

    self.tags = @pending_tag_names.map { |name| user.tags.find_or_create_by(name:) }
  end
end
