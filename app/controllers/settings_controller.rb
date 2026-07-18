class SettingsController < ApplicationController
  TABS = %w[goals filters appearance follow_ups auto_archiving danger_zone].freeze

  SUCCESS_MESSAGES = {
    "goals" => "Goal settings saved.",
    "filters" => "Filter settings saved.",
    "appearance" => "Appearance settings saved.",
    "follow_ups" => "Follow-up settings saved.",
    "auto_archiving" => "Auto-archiving settings saved."
  }.freeze

  def edit
    @settings = Current.user.all_settings
    @active_tab = active_tab
  end

  def update
    @user = Current.user

    if @user.update_settings(coerced_settings_params)
      redirect_to settings_path(tab: active_tab), success: SUCCESS_MESSAGES.fetch(active_tab, "Settings updated successfully.")
    else
      @settings = @user.all_settings
      @active_tab = active_tab
      render :edit, status: :unprocessable_content, error: "Failed to update settings."
    end
  end

  def reset
    if Current.user.reset_all_settings
      flash[:success] = "Settings reset to defaults."
    else
      flash[:error] = "Failed to reset settings."
    end
    redirect_to settings_path(tab: active_tab)
  end

  private

  def active_tab
    TABS.include?(params[:tab]) ? params[:tab] : TABS.first
  end

  def settings_params
    return {}.with_indifferent_access unless params[:settings].respond_to?(:permit!)

    # Safe because every submitted value is read by schema path, coerced, and validated before persistence.
    params[:settings].permit!.to_h.with_indifferent_access
  end

  def coerced_settings_params
    coerce_settings(settings_params, User::Settings::SCHEMA)
  end

  # Coercion is permissive: uncoercible values pass through so User::Settings.sanitize
  # remains the source of truth and drops anything invalid before persistence.
  def coerce_settings(input, schema)
    input.each_with_object({}.with_indifferent_access) do |(key, raw_value), coerced|
      schema_entry = schema[key]
      next if schema_entry.nil?

      coerced[key] =
        if schema_entry.key?(:default)
          coerce_setting_value(schema_entry[:default], raw_value)
        elsif raw_value.is_a?(Hash)
          coerce_settings(raw_value, schema_entry)
        end
    end
  end

  def coerce_setting_value(default, raw_value)
    case default
    when Integer
      Integer(raw_value, exception: false) || raw_value
    when true, false
      { "true" => true, "false" => false }.fetch(raw_value, raw_value)
    else
      raw_value
    end
  end
end
