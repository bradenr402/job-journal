# Disable default field_with_errors div wrappers to preserve layout
ActionView::Base.field_error_proc = ->(html_tag, _instance) { html_tag }
