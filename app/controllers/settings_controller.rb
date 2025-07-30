class SettingsController < ApplicationController
  def edit
    @settings = Current.user.all_settings
  end

  def update
    @user = Current.user
    updated = true

    User::DEFAULT_SETTINGS.keys.each do |key|
      raw_value = params[key.to_s]
      default_value = User::DEFAULT_SETTINGS[key]
      value = parse_setting_value(raw_value, default_value)

      current_setting = @user.get_setting(key)
      next if current_setting == value && value == default_value

      updated &&= @user.set_setting(key, value)
    end

    if updated
      redirect_to settings_path, success: 'Settings updated successfully.'
    else
      @settings = @user.all_settings
      render :edit, status: :unprocessable_entity, error: 'Failed to update settings.'
    end
  end

  def reset
    if Current.user.reset_all_settings
      flash[:success] = 'Settings reset to defaults successfully.'
    else
      flash[:error] = 'Failed to reset settings.'
    end
    redirect_to settings_path
  end

  private

  def parse_setting_value(raw_value, default_value)
    case raw_value
    when 'true'
      true
    when 'false'
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
