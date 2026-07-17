class Note < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :notable, polymorphic: true, touch: true

  # Validations
  validates :content, presence: true

  # Scope
  scope :recent, ->(timeframe = 7.days) { where(updated_at: timeframe.ago..) }

  # Instance Methods
  def job_lead
    return notable if notable.is_a? JobLead

    notable&.job_lead
  end

  def title
    case notable
    when JobLead
      job_lead = notable
      "#{job_lead.title} @ #{job_lead.company}"
    when Interview
      interview = notable
      interview.title
    else
      notable.model_name.human.titlecase
    end
  end
end
