class ApplicationController < ActionController::Base
  include Authentication
  before_action :touch_current_session

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  add_flash_types :success, :error

  private

  def allowed_setting(value, path:, use_user_setting: false)
    return value if User::Settings.valid_value?(value, path: path)
    return unless use_user_setting

    value = Current.user.get_setting(*path)
    return value if User::Settings.valid_value?(value, path: path)

    User::Settings::DEFAULT_SETTINGS.dig(*path)
  end

  def valid_job_lead_type(use_user_setting: false)
    type = params[:job_lead_type]
    allowed_setting(type, path: [ :filters, :job_leads ], use_user_setting:)
  end

  def valid_status
    status = params[:status]
    status if status.in? JobLead::STATUSES
  end

  def valid_notable_type
    type = params[:notable_type]
    type if type.in? %w[JobLead Interview]
  end

  def valid_note_type(use_user_setting: false)
    type = params[:note_type]
    allowed_setting(type, path: [ :filters, :notes ], use_user_setting:)
  end

  def valid_date_range(use_user_setting: false)
    type = params[:date_range]
    allowed_setting(type, path: [ :filters, :interviews ], use_user_setting:)
  end

  def touch_current_session
    Current.session&.touch
  end
end
