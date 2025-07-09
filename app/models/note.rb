class Note < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :notable, polymorphic: true, touch: true

  # Instance Methods
  def job_lead
    notable if notable.is_a? JobLead
    notable.job_lead if notable&.job_lead
  end
end
