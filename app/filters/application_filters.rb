# Declarative, param-driven filtering and sorting shared by the index actions and search.
#
# Subclasses describe their options with the `filter` and `sort_option` class macros:
#
#   class WidgetFilters < ApplicationFilters
#     filter :color, allowed: %w[ red green blue ] do |scope, color|
#       scope.where(color:)
#     end
#
#     sort_option :created, column: :created_at, direction: :desc
#   end
#
# `filter` accepts:
#   param:   query param the value is read from (defaults to the filter name)
#   allowed: list of valid values (anything else is ignored); nil accepts any
#   default: value used when the param is absent or invalid
#   setting: user settings path used as the fallback when `use_settings` is on
#   parse:   callable turning the raw param into a final value; skips `allowed`,
#            setting fallback, and default fallback
#
# The block receives the current scope and the value, and runs against the
# filters instance (so it can reference `user`). It is only invoked when the
# value is present and differs from the default.
#
# `sort_option` accepts:
#   column:    the column to order by (defaults to the sort_option name)
#   direction: the default direction (defaults to :asc)
#   text:      set to `true` for case-insensitive ordering.
#
# Models are inferred from the class name (WidgetFilters -> Widget).
class ApplicationFilters
  Filter = Data.define(:name, :param, :allowed, :default, :setting, :parse, :apply)
  SortOption = Data.define(:name, :column, :direction, :text)

  DIRECTIONS = %w[ asc desc ].freeze

  class << self
    def filters = @filters ||= {}
    def sort_options = @sort_options ||= {}

    def options_for(name) = filters.fetch(name.to_sym).allowed

    def model = @model ||= name.delete_suffix("Filters").constantize

    private

    def filter(name, param: name, allowed: nil, default: nil, setting: nil, parse: nil, &apply)
      filter_key = name.to_sym
      filters[filter_key] = Filter.new(name: filter_key, param: param.to_sym, allowed:, default:, setting:, parse:, apply:)
      define_method(name) { value_of filter_key }
    end

    def sort_option(name, column: name, direction: :asc, text: false)
      sort_name = name.to_s
      direction = direction.to_s
      validate_sort_direction! direction
      sort_options[sort_name] = SortOption.new(name: sort_name, column:, direction:, text:)
    end

    def validate_sort_direction!(direction)
      raise ArgumentError, "Invalid sort direction: #{direction.inspect}" unless direction.in?(DIRECTIONS)
    end
  end

  attr_reader :user

  def initialize(params = {}, user: nil, use_settings: false)
    @params = params
    @user = user
    @use_settings = use_settings && user.present?
    @values = {}
  end

  # Applies every active filter, then any requested sort, to the scope.
  def apply(scope)
    scope = self.class.filters.each_value.reduce(scope) do |current, filter|
      filtered?(filter.name) ? instance_exec(current, value_of(filter.name), &filter.apply) : current
    end

    apply_sort(scope)
  end

  # True when the filter holds a value other than its default.
  def filtered?(name)
    filter = self.class.filters.fetch(name.to_sym)
    value = value_of filter.name

    value.present? && value != filter.default
  end

  def any_active? = self.class.filters.keys.any? { filtered? it } || sort.present?

  def sort = @params[:sort].presence_in(self.class.sort_options.keys)

  def sort_direction
    option = self.class.sort_options[sort]
    return unless option

    @params[:direction].to_s.presence_in(DIRECTIONS) || option.direction
  end

  # Query params reflecting the current filter and sort state, for link building.
  def to_params
    result = self.class.filters.each_value.with_object({}) do |filter, params|
      next unless include_in_params?(filter)

      value = value_of filter.name
      params[filter.param] = value.is_a?(Array) ? value.join(",") : value
    end

    result.merge!(sort:, direction: sort_direction) if sort
    result
  end

  def params_with(**overrides) = to_params.merge(**overrides).compact_blank

  # Params that toggle `value` on or off for the given filter.
  # * Multi-value filters (arrays) add or remove the value.
  # * Single-value filters switch to `value`, or back to `off` when it is already selected.
  def toggle_params(name, value, off: nil)
    filter = self.class.filters.fetch(name.to_sym)
    current = value_of filter.name

    if current.is_a?(Array)
      values = current.include?(value) ? current.without(value) : current.including(value)
      params_with(filter.param => values.join(","))
    else
      params_with(filter.param => current == value ? off : value)
    end
  end

  # Params that activate the given sort with its default direction, or clear
  # the sort entirely when `name` is nil.
  def sort_params(name: nil)
    return params_with(sort: nil, direction: nil) if name.nil?

    option = self.class.sort_options.fetch(name.to_s)
    params_with(sort: option.name, direction: option.direction)
  end

  # Params that reverse the current sort direction.
  def direction_toggle_params
    params_with(direction: sort_direction == "asc" ? "desc" : "asc")
  end

  private

  # A filter belongs in generated params when it is active, or when its value
  # explicitly overrides a different user-setting fallback (e.g. a default of
  # "all" chosen over a saved setting) — otherwise the link would revert it.
  def include_in_params?(filter)
    return true if filtered?(filter.name)

    @use_settings && filter.setting.present? && value_of(filter.name) != setting_value(filter)
  end

  def value_of(name)
    @values.fetch(name) { @values[name] = parse_value(self.class.filters.fetch(name)) }
  end

  def parse_value(filter)
    raw = @params[filter.param]
    return filter.parse.call(raw) if filter.parse

    value = raw.to_s.presence
    return value if allowed?(filter, value)
    return setting_value(filter) if @use_settings && filter.setting

    filter.default
  end

  def allowed?(filter, value)
    filter.allowed.nil? ? value.present? : value.in?(filter.allowed)
  end

  def setting_value(filter)
    value = user.get_setting(*filter.setting)
    allowed?(filter, value) ? value : filter.default
  end

  def apply_sort(scope)
    option = self.class.sort_options[sort]
    return scope unless option

    attribute = self.class.model.arel_table[option.column]
    attribute = attribute.lower if option.text
    ordering = sort_direction == "desc" ? attribute.desc : attribute.asc

    scope.reorder(ordering.nulls_last)
  end
end
