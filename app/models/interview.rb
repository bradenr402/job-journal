class Interview < ApplicationRecord
  # Associations
  belongs_to :job_lead
  has_many :notes, as: :notable, dependent: :destroy

  # Validations
  validates :job_lead, presence: true
  validates :scheduled_at, presence: true
  delegate :user, to: :job_lead

  validates :interviewer, length: { maximum: 255 }, allow_blank: true
  validates :location, length: { maximum: 255 }, allow_blank: true
  validates :call_url, format: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true

  validates :rating, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }, allow_nil: true

  # Callbacks
  before_validation :convert_zero_rating_to_nil
  after_save :update_job_lead_status

  # Scopes
  scope :upcoming, -> { where(scheduled_at: Time.current..7.days.from_now) }
  scope :future, -> { where(scheduled_at: Time.current..) }
  scope :past, -> { where(scheduled_at: ..Time.current) }

  # Instance Methods
  private

  def convert_zero_rating_to_nil
    self.rating = nil if rating == 0
  end

  def update_job_lead_status
    job_lead.interview!
  end
end
