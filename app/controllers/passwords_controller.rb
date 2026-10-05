class PasswordsController < ApplicationController
  layout "auth"

  allow_unauthenticated_access
  rate_limit to: 5, within: 3.minutes, only: :create, with: -> { redirect_to new_password_path, error: "Try again later." }
  rate_limit to: 5, within: 3.minutes, only: :update, with: -> { redirect_to new_password_path, error: "Try again later." }
  before_action :set_user_by_token, only: %i[ edit update ]

  before_action only: %i[new create sent] do
    redirect_to dashboard_path, notice: "You are already signed in." if authenticated?
  end

  def new
  end

  def create
    if user = User.find_by(email_address: params[:email_address])
      PasswordsMailer.reset(user).deliver_later
    end

    session[:password_reset_email] = params[:email_address].presence
    redirect_to sent_passwords_path
  end

  # GET /passwords/sent
  def sent
    @email_address = session.delete(:password_reset_email)
  end

  def edit
  end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      terminate_sessions @user.sessions
      start_new_session_for @user
      redirect_to dashboard_path, success: "Password updated. You’re signed in."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_user_by_token
    @user = User.find_by_password_reset_token!(params[:token])
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_password_path, error: "That reset link is invalid or has expired. Request a new one below."
  end
end
