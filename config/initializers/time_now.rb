module Now
  def now?(threshold: 1.minute)
    (self - Time.current).abs <= threshold
  end
end

# Extend Time and ActiveSupport::TimeWithZone
Time.include(Now)
ActiveSupport::TimeWithZone.include(Now)
