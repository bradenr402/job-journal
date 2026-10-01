class RegistrationsController < ApplicationController
  layout "auth", only: %i[ new create ]

  allow_unauthenticated_access only: [ :new, :create ]
  before_action :resume_session, only: [ :new, :create ]

  before_action only: %i[new create] do
    redirect_to dashboard_path, notice: "You are already signed in." if authenticated?
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      start_new_session_for @user
      redirect_to dashboard_path, success: "You&#8217;ve successfully signed up for JobJournal. Welcome!"
    else
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    @user = Current.user

    unless deletion_confirmed?
      return redirect_back fallback_location: edit_account_path,
        error: "To delete your account, enter your current password and type DELETE exactly as shown."
    end

    if @user.destroy
      cookies.delete(Authentication::SESSION_COOKIE_NAME)
      redirect_to new_session_path, notice: "Your account has been deleted."
    else
      redirect_back fallback_location: edit_account_path, error: "Failed to delete your account. Please try again."
    end
  end

  private

  def deletion_confirmed?
    params[:confirm_delete].to_s.strip == "DELETE" && @user.authenticate(params[:current_password].to_s)
  end

  def user_params
    params.expect(user: [ :email_address, :password, :password_confirmation ])
  end
end
