class SettingsController < ApplicationController
  TABS = %w[goals filters appearance follow_ups auto_archiving danger_zone].freeze

  def edit
    @settings = Current.user.all_settings
    @active_tab = active_tab
  end

  def update
    @user = Current.user
    updated = true

    User::DEFAULT_SETTINGS.keys.select { |key| params.key?(key.to_s) }.each do |key|
      raw_value = params[key.to_s]
      default_value = User::DEFAULT_SETTINGS[key]
      value = parse_setting_value(raw_value, default_value)

      current_setting = @user.get_setting(key)
      next if current_setting == value && value == default_value

      updated &&= @user.set_setting(key, value)
    end

    if updated
      redirect_to settings_path(tab: active_tab), success: "Settings updated successfully."
    else
      @settings = @user.all_settings
      @active_tab = active_tab
      render :edit, status: :unprocessable_entity, error: "Failed to update settings."
    end
  end

  def reset
    if Current.user.reset_all_settings
      flash[:success] = "Settings reset to defaults successfully."
    else
      flash[:error] = "Failed to reset settings."
    end
    redirect_to settings_path(tab: active_tab)
  end

  private

  def active_tab
    TABS.include?(params[:tab]) ? params[:tab] : TABS.first
  end

  def parse_setting_value(raw_value, default_value)
    case raw_value
    when "true"
      true
    when "false"
      false
    else
      if raw_value.to_s.match?(/\A\d+\z/) && default_value.is_a?(Integer)
        raw_value.to_i
      else
        raw_value
      end
    end
  end
end
