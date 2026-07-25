module SearchHelper
  def clear_search_filter_button(filters, param, query:, scope:)
    link_to(
      icon("eraser-filled", class: "size-4 shrink-0") + "Clear",
      search_path(filters.params_with(q: query, scope:, param => nil)),
      class: "btn btn-xs btn-destructive btn-muted"
    )
  end
end
