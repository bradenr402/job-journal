class Interview < ApplicationRecord
  # Associations
  belongs_to :job_lead
  has_many :notes, as: :notable, dependent: :destroy

  # Normalizations
  %i[interviewer location].each do |attribute|
    normalizes attribute, with: :squish.to_proc
  end

  # Validations
  validates :job_lead, presence: true
  validates :scheduled_at, presence: true
  validates :interviewer, length: { maximum: 255 }, presence: true
  validates :location, length: { maximum: 255 }, allow_blank: true
  validates :call_url, format: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true

  validates :rating, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }, allow_nil: true

  # Callbacks
  before_validation :convert_zero_rating_to_nil

  # Delegations
  delegate :user, to: :job_lead

  # Scopes
  scope :upcoming, -> { where(scheduled_at: Time.current.beginning_of_day..7.days.from_now) }
  scope :recent, -> { where(scheduled_at: 3.days.ago.beginning_of_day..Time.current) }
  scope :future, -> { where(scheduled_at: Time.current..) }
  scope :past, -> { where(scheduled_at: ..Time.current) }

  # Instance Methods
  def future? = scheduled_at.future?
  alias scheduled? future?

  def past? = scheduled_at.past?
  alias completed? past?

  private

  def convert_zero_rating_to_nil
    self.rating = nil if rating == 0
  end
end
