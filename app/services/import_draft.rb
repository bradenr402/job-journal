# The in-progress state of a CSV import (file, column mapping, and per-row
# choices), kept in the cache so every step has a URL that survives a refresh.
class ImportDraft
  TTL = 1.day

  class NotFound < StandardError; end

  attr_reader :id

  def self.create(user:, **attributes)
    new(user:, id: SecureRandom.urlsafe_base64(12), attributes: attributes.deep_stringify_keys).tap(&:save)
  end

  def self.find(user:, id:)
    attributes = Rails.cache.read(key(user, id)) or raise NotFound
    new(user:, id:, attributes:)
  end

  def self.key(user, id) = "import_drafts/#{user.id}/#{id}"

  def initialize(user:, id:, attributes:)
    @user = user
    @id = id
    @attributes = attributes
  end

  def to_param = id
  def [](key) = @attributes[key.to_s]

  def update(changes)
    @attributes.merge!(changes.deep_stringify_keys)
    save
  end

  def save = Rails.cache.write(self.class.key(@user, id), @attributes, expires_in: TTL)
  def destroy = Rails.cache.delete(self.class.key(@user, id))

  def import
    JobLeadImport.new(
      user: @user,
      csv: self[:csv],
      mapping: self[:mapping],
      overrides: self[:overrides] || {},
      on_duplicate: self[:on_duplicate],
      date_format: self[:date_format],
      save_errors: self[:save_errors] || {}
    )
  end
end
