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
  scope :upcoming, ->(timeframe = 7.days) { where(scheduled_at: Time.current.beginning_of_day..timeframe.from_now) }
  scope :recent, ->(timeframe = 3.days) { where(scheduled_at: timeframe.ago.beginning_of_day..Time.current) }
  scope :future, -> { where(scheduled_at: Time.current..) }
  scope :past, -> { where(scheduled_at: ..Time.current) }

  # Instance Methods
  def future? = scheduled_at.future?
  alias scheduled? future?

  def past? = scheduled_at.past?
  alias completed? past?

  def title
    if persisted?
      "Interview with #{interviewer} - #{job_lead.title} @ #{job_lead.company}"
    else
      "Interview - #{job_lead.title} @ #{job_lead.company}"
    end
  end

  def calendar_event(request)
    event = Icalendar::Event.new
    event.dtstart = scheduled_at
    event.dtend = scheduled_at.advance(hours: 1)
    event.summary = title
    event.description = calendar_description
    event.location = location.presence
    event.url = call_url.presence
    event.uid = "interview-#{id}@#{request.host}"

    event
  end

  private

  def calendar_description
    link = Rails.application.routes.url_helpers.interview_url(self, Rails.application.config.action_mailer.default_url_options)
    [
      "JobJournal: #{link}",
      notes.map(&:content).join("\n").presence
    ].compact.join("\n\n")
  end

  def convert_zero_rating_to_nil
    self.rating = nil if rating == 0
  end
end
