class Note < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :notable, polymorphic: true, touch: true

  # Validations
  validates :content, presence: true

  # Scope
  scope :recent, -> { where(updated_at: 7.days.ago..) }

  # Instance Methods
  def job_lead
    notable if notable.is_a? JobLead
    notable.job_lead if notable&.job_lead
  end

  def title
    case notable
    when JobLead
      "#{notable.title} @ #{notable.company}"
    when Interview
      job_lead = notable.job_lead
      "Interview - #{job_lead.title} @ #{job_lead.company}"
    else
      notable.model_name.human.titlecase
    end
  end
end
