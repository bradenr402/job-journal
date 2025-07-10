class User < ApplicationRecord
  # Authentication
  has_secure_password

  # Associations
  has_many :sessions, dependent: :destroy
  has_many :job_leads, dependent: :destroy
  has_many :notes, dependent: :destroy
  has_many :interviews, through: :job_leads
  has_many :tags, dependent: :destroy

  # Normalizations
  normalizes :email_address, with: -> { it.strip.downcase }

  # Validations
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true

  # Aliases
  alias_attribute :email, :email_address
end
