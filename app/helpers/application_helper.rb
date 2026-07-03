module ApplicationHelper
  def page_title
    title = content_for(:title).presence || "JobJournal"
    "JobJournal".in?(title) ? title : "#{title} • JobJournal"
  end

  def number_with_sign(number, **options)
    sign =
      if number.zero?
        options[:zero_sign].presence
      elsif number.positive?
        "+"
      else
        "-"
      end

    formatted = number_with_precision(number.abs, **options)
    "#{sign}#{formatted}"
  end

  # Inserts zero-width spaces (ZWSP) after "/" and "-" in URLs or long strings,
  # allowing them to wrap only at these characters for clean, readable line breaks
  # while preventing overflow in containers. Use in views like:
  # <%= link_to line_wrap_url(url), url %>
  def line_wrap_url(text)
    safe_join(
      text.to_s.split(/([\/-])/).map { |part| part.match?(/[\/-]/) ? part + "\u200B" : part }
    )
  end

  def icon(icon, **kwargs)
    return unless icon.present?

    icon_tag = inline_svg_tag("icons/#{icon}.svg", **kwargs)

    if icon_tag.include?("SVG file not found")
      raise ArgumentError, "Unknown icon: #{icon.inspect} (expected app/assets/images/icons/#{icon}.svg)"
    end

    icon_tag
  end

  def icon_for_status(status, **kwargs)
    icon_name =
      case status.to_s
      when "lead" then "briefcase"
      when "applied" then "application"
      when "interview" then "interview"
      when "offer" then "offer"
      when "accepted" then "check-circle"
      when "rejected" then "x-circle"
      else "circle"
      end

    icon icon_name, **kwargs
  end
end
