class JobLead < ApplicationRecord
  # Constants

  # Array of status types for filtering
  STATUSES = %w[lead applied interview offer rejected accepted].freeze

  # STATUS_QUALITY maps each job lead status to a numeric weight representing its value
  # when comparing the effectiveness of job lead sources.
  #
  # - :lead      (5):   A saved opportunity, but no action taken yet. Low value, as many leads never progress.
  # - :applied   (20):  Indicates user effort, but most applications do not result in interviews.
  # - :interview (50):  A significant milestone; the source produced a real opportunity.
  # - :offer     (90):  The source led to a job offer, which is a strong indicator of quality.
  # - :accepted  (100): The ultimate goal; the source resulted in a successful hire.
  # - :rejected  (0):   No longer an active or valuable lead for comparison purposes.
  STATUS_QUALITY = {
    lead:      5,
    applied:   20,
    interview: 50,
    offer:     90,
    accepted:  100,
    rejected:  0
  }.freeze

  # Attributes
  attr_reader :pending_tag_names

  # Associations
  belongs_to :user
  has_many :notes, as: :notable, dependent: :destroy
  has_many :interviews, dependent: :destroy
  accepts_nested_attributes_for :interviews

  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings

  # Normalizations
  %i[title company salary contact location source].each do |attribute|
    normalizes attribute, with: :squish.to_proc
  end

  # Validations
  validates :company, presence: true
  validates :title, presence: true
  validates :application_url, presence: true, uniqueness: true, format: URI::DEFAULT_PARSER.make_regexp(%w[http https])
  validates :offer_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  validates :applied_at, comparison: { less_than_or_equal_to: -> { Time.current } }, allow_nil: true
  validates :offer_at, comparison: { less_than_or_equal_to: -> { Time.current } }, allow_nil: true
  validates :rejected_at, comparison: { less_than_or_equal_to: -> { Time.current } }, allow_nil: true
  validates :accepted_at, comparison: { less_than_or_equal_to: -> { Time.current } }, allow_nil: true

  validate :single_terminal_status
  validate :offer_amount_presence_for_offer_at

  # Callbacks
  before_validation :update_status, on: :update
  after_save_commit :assign_tags

  # Scopes
  scope :lead, -> {
    where(applied_at: nil, offer_at: nil, rejected_at: nil, accepted_at: nil)
      .where.not(id: JobLead.joins(:interviews).select(:id))
  }

  scope :applied, -> {
    where.not(applied_at: nil)
      .where(offer_at: nil, rejected_at: nil, accepted_at: nil)
      .left_outer_joins(:interviews)
      .where(interviews: { id: nil })
  }

  scope :interview, -> {
    joins(:interviews).distinct
      .where(offer_at: nil, rejected_at: nil, accepted_at: nil)
  }

  scope :offer, -> {
    where.not(offer_at: nil)
      .where(rejected_at: nil, accepted_at: nil)
  }

  scope :rejected, -> {
    where.not(rejected_at: nil)
  }

  scope :accepted, -> {
    where.not(accepted_at: nil)
  }

  scope :with_status, ->(status) {
    raise ArgumentError, 'Invalid status' unless STATUSES.include?(status.to_s)
    public_send(status.to_s)
  }

  scope :with_any_status, ->(statuses) {
    statuses = statuses.map(&:to_s)
    invalid_statuses = statuses - STATUSES
    raise ArgumentError, "Invalid status: #{invalid_statuses.join(', ')}" if invalid_statuses.any?

    union_sql = statuses.map { public_send(it).select(:id).to_sql }.join(' UNION ')
    where(id: from("(#{union_sql}) AS unioned").select(:id))
  }

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  scope :stale_for_user, ->(user) do
    cutoff_date = user.get_setting(:job_lead_stale_after_days).days.ago

    active
      .lead
      .where(created_at: ..cutoff_date)
  end

  scope :application_follow_up_for_user, ->(user) do
    end_date = user.get_setting(:application_follow_up_days).days.ago
    start_date = end_date - user.get_setting(:suggest_follow_up_days).days

    active
      .applied
      .where(applied_at: start_date..end_date)
  end

  scope :interview_follow_up_for_user, ->(user) do
    end_date = user.get_setting(:interview_follow_up_days).days.ago
    start_date = end_date - user.get_setting(:suggest_follow_up_days).days

    joins(:interviews)
      .active
      .interview
      .where(interviews: { scheduled_at: start_date..end_date })
  end

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
  def inferred_status
    return 'accepted' if accepted_at?
    return 'rejected' if rejected_at?
    return 'offer' if offer_at?
    return 'interview' if interviews.exists?
    return 'applied' if applied_at?
    'lead'
  end
  alias status inferred_status

  STATUSES.each do |status|
    define_method("#{status}?") { inferred_status == status }
  end

  STATUSES.reject { it.in? %w[ lead interview ] }.each do |status|
    define_method("#{status}!") do
      update!("#{status}_at": Time.current)
    end
  end

  def previous_status
    timeline = {
      'lead' => created_at,
      'applied' => applied_at,
      'interview' => interviews.minimum(:scheduled_at),
      'offer' => offer_at,
      'rejected' => rejected_at,
      'accepted' => accepted_at
    }.compact

    sorted_statuses = timeline.sort_by { |_, time| time }.map(&:first)

    current_index = sorted_statuses.index(inferred_status)

    return sorted_statuses[current_index - 1] if current_index && current_index > 0

    nil
  end

  def last_interview_at = interviews.past.order(scheduled_at: :desc).first&.scheduled_at
  def next_interview_at = interviews.future.order(scheduled_at: :asc).first&.scheduled_at

  def latest_status_at
    case inferred_status
    when 'lead' then  created_at
    when 'applied' then  applied_at
    when 'interview' then next_interview_at || last_interview_at
    when 'offer' then  offer_at
    when 'rejected' then  rejected_at
    when 'accepted' then  accepted_at
    else
      nil
    end
  end

  def source_quality
    self.class.status_quality(inferred_status)
  end

  def type = archived? ? 'archived' : 'active'

  def active? = archived_at.nil?
  def archived? = archived_at.present?

  def archive! = update(archived_at: Time.current)
  def unarchive! = update(archived_at: nil)

  def stale? = created_at.before?(user.get_setting(:job_lead_stale_after_days).days.ago)

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

      interview_count = group.count { |lead| status_quality(lead.status) == STATUS_QUALITY[:interview] }
      offer_count     = group.count { |lead| status_quality(lead.status) == STATUS_QUALITY[:offer] }

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

  # Class Methods
  def self.cleanup_for_user(user)
    stale_days = user.get_setting(:job_lead_stale_after_days)
    archive_days = user.get_setting(:auto_archive_after_stale_days)

    total_days = stale_days + archive_days
    cutoff_date = total_days.days.ago

    stale_for_user(user).where(created_at: ..cutoff_date).find_each do |lead|
      lead.archive!
    end
  end

  private

  def update_status
    if offer_amount_changed? && offer_amount.present? && !offer_at.present?
      self.offer!
    end

    auto_archive_rejected_leads_enabled = user.get_setting(:auto_archive_rejected_leads_enabled)

    if auto_archive_rejected_leads_enabled && rejected_at_changed? && rejected? && !archived?
      self.archive!
    end
  end

  def assign_tags
    return if @pending_tag_names.blank?

    self.tags = @pending_tag_names.map { |name| user.tags.find_or_create_by(name:) }
  end

  def single_terminal_status
    errors.add(:base, 'cannot be both rejected and accepted') if rejected_at? && accepted_at?
  end

  def offer_amount_presence_for_offer_at
    errors.add(:base, 'cannot advance to Offer without specifying an offer amount') if offer_at? && !offer_amount?
  end
end
