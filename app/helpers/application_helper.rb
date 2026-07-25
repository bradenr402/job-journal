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
      layout = user_setting(:layouts, layout) || User::DEFAULT_SETTINGS.dig(:layouts, layout)
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

  def user_setting(*path) = Current.user&.get_setting(*path)

  def number_with_sign(number, **options)
    zero_sign = options.delete :zero_sign
    sign =
      if number.zero?
        zero_sign.presence
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

  def quote(text) = safe_join([ "“", text, "”" ])

  def job_lead_count_text(count, state: nil, tags: nil, status: nil, source: nil)
    capture do
      label = state.present? && state != "all" ? "#{state} job lead" : "job lead"

      concat pluralize(count, label).gsub(/\A0/, "No")

      filters = []

      filters << "status: #{tag.span quote(status.to_s.humanize), class: "font-semibold text-light"}" if status.present?
      filters << "source: #{tag.span quote(source), class: "font-semibold text-light"}" if source.present?

      if tags.present?
        tag_label = "tag".pluralize(tags.size)
        tags_list = tags.map { |t| tag.span t, class: "font-semibold text-light" }.join(", ")

        filters << [ tag_label, tags_list ].join(": ")
      end

      if filters.any?
        concat " with #{filters.to_sentence}".html_safe
      end
    end
  end

  def interview_count_text(count, timeframe: nil, rating: nil)
    capture do
      label = timeframe.present? && timeframe != "all" ? "#{timeframe} interview" : "interview"

      concat pluralize(count, label).gsub(/\A0/, "No")

      if rating.present?
        rating_text = rating == "unrated" ? "No rating" : pluralize(rating, "star")

        concat " with rating: "
        concat tag.span(quote(rating_text), class: "font-semibold text-light")
      end
    end
  end

  def note_count_text(count, job_lead_state: nil, notable: nil)
    label = "#{human notable} note".downcase.squish
    label = "#{job_lead_state} #{label}" if job_lead_state.present? && job_lead_state != "all"

    pluralize(count, label).gsub(/\A0/, "No")
  end

  def search_empty_results_text(scope, query: nil, status: nil, timeframe: nil, rating: nil, notable: nil)
    return "No search query provided" if query.blank?

    base =
      case scope
      when "job_leads" then job_lead_count_text(0, status:)
      when "interviews" then interview_count_text(0, timeframe:, rating:)
      when "notes" then note_count_text(0, notable:)
      else "No results"
      end.html_safe

    safe_join([ base, " found for ", quote(query), "." ])
  end

  # Inserts zero-width spaces (ZWSP) after "/" and "-" in URLs or long strings,
  # allowing them to wrap only at these characters for clean, readable line breaks
  # while preventing overflow in containers. Use in views like:
  # <%= link_to line_wrap_url(url), url %>
  def line_wrap_url(text)
    return unless text.present?

    parts =
      text.to_s
        .split(/([\/-])/)
        .map { |part| part.match?(%r{[/-]}) ? "#{part}\u200B" : part }

    safe_join parts
  end

  def url_without_scheme(url) = url&.sub(%r{\Ahttps?://}, "")
  def url_without_query(url) = url&.sub(/\?.*\z/, "")
  def url_without_scheme_or_query(url) = url_without_scheme(url_without_query(url))
  def display_url(url) = line_wrap_url(url_without_scheme_or_query(url))

  def icon(icon, **kwargs)
    return unless icon.present?

    icon_tag = inline_svg_tag("icons/#{icon}.svg", **kwargs)

    if icon_tag.include?("SVG file not found")
      raise ArgumentError, "Unknown icon: #{icon.inspect} (expected app/assets/images/icons/#{icon}.svg)"
    end

    icon_tag
  end

  def icon_name_for_status(status)
    status_icon_map = {
      lead: "briefcase",
      applied: "application",
      interview: "interview",
      offer: "offer",
      accepted: "check-circle",
      rejected: "x-circle"
    }

    status_icon_map.fetch(status.to_sym) do
      raise ArgumentError, "Unknown status: #{status.inspect}. Expected one of: #{status_icon_map.keys.join(", ")}"
    end
  end

  def icon_for_status(status, **kwargs)
    icon icon_name_for_status(status), **kwargs
  end

  def filter_row_label(text, icon_name: nil)
    tag.span(
      class: "filter-label",
      style: "view-transition-name: filter-row-label-#{text.parameterize}"
    ) do
      concat icon(icon_name, class: "size-4 shrink-0") if icon_name.present?
      concat text
    end
  end

  def filter_link(path:, value:, icon_name:, selected:, label: value.titlecase, tag_class: nil, context: nil)
    tag_classes = [
      "tag",
      "tag-filter",
      tag_class,
      ("tag-selected" if selected)
    ]

    link_to(
      path,
      class: tag_classes,
      style: ("view-transition-name: #{context}-#{value.to_s.parameterize}" if context)
    ) do
      concat icon(icon_name, class: "size-4 -ml-px shrink-0")
      concat tag.span(label)
      concat icon("x-mini") if selected && value != "all"
    end
  end

  def human(string)
    string.presence.to_s.underscore.humanize
  end

  def back_path(fallback: root_path)
    request.referer || fallback
  end
end
