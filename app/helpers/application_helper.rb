module ApplicationHelper
  LAYOUT_CLASSES = {
    "grid" => {
      collection: "card-grid",
      item: "card"
    },
    "list" => {
      collection: "card-list",
      item: "card"
    },
    "minimal" => {
      collection: "minimal-item-list",
      item: "minimal-item"
    }
  }

  def resolve_layout(layout)
    unless layout.is_a?(String) || layout.is_a?(Symbol)
      raise ArgumentError, "Expected layout to be a String or Symbol, got #{layout.class.name}"
    end

    if layout.is_a?(Symbol)
      layout = user_setting(layout) || User::DEFAULT_SETTINGS[layout]
    end

    unless LAYOUT_CLASSES.key?(layout)
      raise ArgumentError, "Unknown layout: #{layout.inspect}. Expected one of: #{LAYOUT_CLASSES.keys.join(", ")}"
    end

    layout
  end

  def collection_layout_class_names(layout, count:, size: :large)
    layout = resolve_layout(layout)

    layout_class = LAYOUT_CLASSES.dig(layout, :collection)
    return layout_class unless layout == "grid"

    third_col_class = {
      medium: "card-grid-md",
      large: "card-grid-lg"
    }[size.to_sym]

    [
      layout_class,
      (third_col_class if count >= 3 && count != 4)
    ].compact.join(" ")
  end

  def item_layout_class_names(layout)
    layout = resolve_layout(layout)

    LAYOUT_CLASSES.dig(layout, :item)
  end

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

  def option(value, text: value.titlecase, icon: value)
    { text:, value:, icon: }
  end

  def options(*values)
    values.map { option(it) }
  end

  def job_lead_count_text(count, type: nil, tags: nil, status: nil)
    capture do
      label = type.present? && type != "all" ? "#{type} job lead" : "job lead"

      concat pluralize(count, label)

      filters = []

      filters << "status: #{tag.span "“#{status.to_s.humanize}”", class: "font-semibold text-light"}" if status.present?

      if tags.present?
        tag_label = "tag".pluralize(tags.size)
        tags_list = tags.map { |t| tag.span t, class: "font-semibold text-light" }.to_sentence(two_words_connector: ", ")

        filters << [ tag_label, tags_list ].join(": ")
      end

      if filters.any?
        concat " with #{filters.to_sentence}".html_safe
      end
    end
  end

  def interview_count_text(count, type: nil)
    label = type.present? && type != "all" ? "#{type} interview" : "interview"
    pluralize(count, label)
  end

  def note_count_text(count, type: nil, notable: nil)
    label = "#{human notable} note".downcase.squish
    label = "#{type} #{label}" if type.present? && type != "all"

    pluralize(count, label)
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

  def icon_name_for_status(status)
    case status.to_s
    when "lead" then "briefcase"
    when "applied" then "application"
    when "interview" then "interview"
    when "offer" then "offer"
    when "accepted" then "check-circle"
    when "rejected" then "x-circle"
    else "circle"
    end
  end

  def icon_for_status(status, **kwargs)
    icon icon_name_for_status(status), **kwargs
  end

  def filter_link(path:, value:, icon_name:, selected:, label: value.titlecase, tag_class: nil, context: nil)
    contents = [
      icon(icon_name, class: "size-4 -ml-px shrink-0"),
      tag.span(label),
      (icon("x-mini") if selected && value != "all")
    ].compact

    tag_classes = [
      "tag",
      "tag-filter",
      tag_class,
      ("tag-selected" if selected)
    ]

    link_to path, class: "inline-block", style: ("view-transition-name: #{context}-#{value}" if context) do
      tag.span safe_join(contents), class: tag_classes
    end
  end

  def human(string)
    string.presence.to_s.underscore.humanize
  end

  def back_path(fallback: root_path)
    request.referer || fallback
  end
end
