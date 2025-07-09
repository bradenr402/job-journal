module ApplicationHelper
  def number_with_sign(number, **options)
    sign = number.positive? ? '+' : number.negative? ? '-' : ''
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
end
