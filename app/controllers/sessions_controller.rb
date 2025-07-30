class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: 'Try again later.' }

  before_action only: %i[new create] do
    redirect_to root_path, notice: 'You are already signed in.' if authenticated?
  end

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, error: 'Try another email address or password.'
    end
  end

  def destroy
    session = Session.find_by(id: params[:session]) || Current.session

    terminate_session session

    if session == Current.session
      redirect_to new_session_path, notice: 'You have been signed out.'
    else
      redirect_back fallback_location: account_path, notice: 'Session successfully terminated.'
    end
  end

  def destroy_other_sessions
    Session.where(user_id: Current.user.id).where.not(id: Current.session.id).find_each do |session|
      terminate_session session
    end

    redirect_to account_path, notice: 'All other sessions have been terminated.'
  end
end
