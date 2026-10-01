module DashboardDemo
  # Formats <time data-local="time"> elements the way the local_time JavaScript
  # would in the browser, since neither the demo nor the screenshot runs it.
  module LocalTimes
    def self.apply(node, time_zone: Time.zone)
      node.css("time[data-local='time']").each do |element|
        time = Time.iso8601(element["datetime"]).in_time_zone(time_zone)

        element["title"] ||= strftime(time, "%B %e, %Y at %l:%M%P %Z")
        element["data-localized"] = ""
        element.content = strftime(time, element["data-format"])
        element.remove_attribute("data-format24")
      end
    end

    # Ruby's strftime pads %e and %l with a space; local_time's JavaScript doesn't.
    def self.strftime(time, format)
      time.strftime(format.gsub("%e", time.day.to_s).gsub("%l", time.strftime("%-l")))
    end
  end
end
