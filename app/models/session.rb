class Session < ApplicationRecord
  RECENCY_MARKS = {
    "1_week" => 1.week,
    "1_month" => 1.month,
    "3_months" => 3.months,
    "6_months" => 6.months
  }.freeze

  ACTIVITY_THROTTLE = 5.minutes

  belongs_to :user

  scope :inactive_since, ->(mark) { where(updated_at: ...RECENCY_MARKS.fetch(mark).ago) }

  def record_activity(ip_address:)
    return if ip_address == self.ip_address && recently_active?

    update_columns(ip_address:, updated_at: Time.current)
  end

  def recently_active?
    updated_at > ACTIVITY_THROTTLE.ago
  end
end
