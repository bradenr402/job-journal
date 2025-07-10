class Tagging < ApplicationRecord
  # Associations
  belongs_to :job_lead, touch: true
  belongs_to :tag

  # Validations
  validates :tag_id, presence: true
  validates :job_lead_id, presence: true
  validates :tag_id, uniqueness: { scope: :job_lead_id }

  # Callbacks
  after_commit :destroy_orphaned_tag, on: :destroy

  # Instance Methods
  private

  def destroy_orphaned_tag
    tag.reload
    tag.destroy if tag.taggings.count.zero?
  end
end
