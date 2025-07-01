class Note < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :notable, polymorphic: true

  # Callbacks
  after_save :touch_notable

  # Instance Methods
  private

  def touch_notable
    notable.touch if notable
  end
end
