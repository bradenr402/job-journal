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
end
