class DeviceInfo
  MOBILE_TYPES = [ "smartphone", "phablet", "feature phone" ].freeze

  def initialize(user_agent)
    @detector = DeviceDetector.new(user_agent)
  end

  def browser
    @detector.name.presence || "Unknown"
  end

  def os
    @detector.os_name.presence
  end

  def device_type
    @detector.device_type.presence&.titleize
  end

  def label
    [ device_type, os ].compact.presence || [ "Unknown device" ]
  end

  def icon_name
    case @detector.device_type
    when *MOBILE_TYPES then "smartphone"
    when "tablet" then "tablet"
    else "computer"
    end
  end
end
