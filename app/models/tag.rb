class Tag < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :taggings, dependent: :destroy
  has_many :job_leads, through: :taggings

  # Normalizations
  normalizes :name, with: -> { it.downcase }

  # Validations
  validates :name, presence: true
  validates :name, uniqueness: { scope: :user_id, case_sensitive: false }

  # Scopes
  scope :unused, -> { left_outer_joins(:taggings).where(taggings: { id: nil }) }

  # Class Methods
  def self.cleanup_unused_for_user(user)
    unused.destroy_all
  end
end
