class Note < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :notable, polymorphic: true

  # Callbacks
  after_save :touch_notable

  # Instance Methods
  def job_lead
    notable if notable.is_a? JobLead
    notable.job_lead if notable&.job_lead
  end

  private

  def touch_notable
    notable.touch if notable
  end
end
