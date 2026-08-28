class Tag < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :taggings, dependent: :destroy
  has_many :job_leads, through: :taggings

  # Normalizations
  normalizes :name, with: -> { it.squish.downcase }

  # Validations
  validates :name, presence: true
  validates :name, uniqueness: { scope: :user_id, case_sensitive: false }

  # Scopes
  scope :unused, -> { left_outer_joins(:taggings).where(taggings: { id: nil }) }
  scope :top_by_usage, -> {
    joins(:taggings)
      .group(:id, :name)
      .order(Arel.sql("COUNT(taggings.id) DESC"))
  }

  # Domain Methods

  # Returns the surviving tag on success (the existing tag when merged,
  # so callers must not assume it is the receiver), or false on failure.
  def rename_to(new_name)
    rename_to!(new_name)
  rescue ActiveRecord::RecordInvalid
    false
  rescue ActiveRecord::RecordNotUnique
    errors.add(:name, :taken)
    false
  end

  def rename_to!(new_name)
    existing_tag = duplicate_named(new_name)

    unless existing_tag
      update!(name: new_name)
      return self
    end

    transaction do
      merge_into!(existing_tag)
      existing_tag
    end
  end

  # Returns the user's other tag that new_name would collide with, if any.
  def duplicate_named(new_name)
    return nil unless persisted?

    user.tags.where.not(id:).find_by(name: self.class.normalize_value_for(:name, new_name))
  end

  # Class Methods
  def self.cleanup_unused_for_user(user)
    user.tags.unused.destroy_all
  end

  private

  # Moves this tag's taggings onto other_tag, dropping the ones that would
  # duplicate a tagging other_tag already has, then removes this tag.
  def merge_into!(other_tag)
    job_lead_ids = taggings.pluck(:job_lead_id)

    taggings.where(job_lead_id: other_tag.taggings.select(:job_lead_id)).delete_all
    taggings.update_all(tag_id: other_tag.id, updated_at: Time.current)
    # delete, not destroy: dependent: :destroy would take the moved taggings with it.
    delete

    # delete_all/update_all skip Tagging's `belongs_to :job_lead, touch: true`.
    JobLead.where(id: job_lead_ids).touch_all if job_lead_ids.any?
  end
end
