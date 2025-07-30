class ApplicationController < ActionController::Base
  include Authentication
  before_action :touch_current_session

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  add_flash_types :success, :error

  private

  def touch_current_session
    Current.session&.touch
  end
end
