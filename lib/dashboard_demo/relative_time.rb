module DashboardDemo
  # Parses the relative times used in data.yml ("3 days ago at 14:30",
  # "in 2 days at 17:16", "today at 09:00", "now") against a fixed "now".
  class RelativeTime
    PATTERN = /\A(?:now|today|(?<in>in )?(?<days>\d+) days? ?(?<ago>ago)?)(?: at (?<hour>\d{1,2}):(?<minute>\d{2}))?\z/

    def initialize(now)
      @now = now
    end

    def parse(value)
      return if value.nil?
      return @now if value == "now"

      match = PATTERN.match(value.to_s.strip) or raise ArgumentError, "Unrecognized demo time: #{value.inspect}"
      days = match[:days].to_i
      raise ArgumentError, "Use \"N days ago\" or \"in N days\": #{value.inspect}" if days.positive? && !match[:in] == !match[:ago]

      time = match[:in] ? @now + days.days : @now - days.days
      match[:hour] ? time.change(hour: match[:hour].to_i, min: match[:minute].to_i) : time
    end
  end
end
