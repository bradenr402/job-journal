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
    terminate_session
    redirect_to new_session_path, notice: 'You have been signed out.'
  end
end
