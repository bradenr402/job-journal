class Passkey < ApplicationRecord
  # Associations
  belongs_to :user

  # Validations
  validates :identifier, presence: true, uniqueness: true
  validates :public_key, presence: true
  validates :name, presence: true
  validates :sign_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Callbacks
  before_validation :generate_identifier, on: :create

  # Scopes
  scope :recent, -> { order(last_used_at: :desc, created_at: :desc) }

  # Instance methods
  def touch_last_used
    update(last_used_at: Time.current)
  end

  def update_sign_count(new_count)
    update(sign_count: new_count)
  end

  private

  def generate_identifier
    self.identifier ||= SecureRandom.hex(32)
  end
end
