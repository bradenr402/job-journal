class Session < ApplicationRecord
  RECENCY_MARKS = {
    "1_week" => 1.week,
    "1_month" => 1.month,
    "3_months" => 3.months,
    "6_months" => 6.months
  }.freeze

  belongs_to :user

  scope :inactive_since, ->(mark) { where(updated_at: ...RECENCY_MARKS.fetch(mark).ago) }
end
