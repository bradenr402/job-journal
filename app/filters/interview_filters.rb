class InterviewFilters < ApplicationFilters
  TIMEFRAMES = %w[ all upcoming completed ].freeze
  RATINGS = %w[ 1 2 3 4 5 unrated ].freeze

  filter :timeframe, allowed: TIMEFRAMES, default: "all", setting: %i[filters interviews] do |scope, timeframe|
    timeframe == "upcoming" ? scope.future : scope.past
  end

  filter :rating, allowed: RATINGS do |scope, rating|
    rating == "unrated" ? scope.where(rating: nil) : scope.where(rating:)
  end

  sort_option :interviewer, text: true

  with_options direction: :desc do
    sort_option :scheduled, column: :scheduled_at
    sort_option :created,   column: :created_at
    sort_option :updated,   column: :updated_at
  end
end
