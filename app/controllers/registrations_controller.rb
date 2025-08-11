class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: [ :new, :create ]
  before_action :resume_session, only: [ :new, :create ]

  before_action only: %i[new create] do
    redirect_to root_path, notice: 'You are already signed in.' if authenticated?
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      start_new_session_for @user
      redirect_to root_path, success: 'You&#8217;ve successfully signed up to JobJournal. Welcome!'
    else
      render :new, status: :unprocessable_entity, error: @user.errors.full_messages.join(', ')
    end
  end

  def destroy
    @user = Current.user

    if @user.destroy
      redirect_to new_session_path, notice: 'Your account has been deleted.'
    else
      redirect_back fallback_location: edit_account_path, error: 'Failed to delete your account. Please try again.'
    end
  end

  private

  def user_params
    params.expect(user: [ :email_address, :password, :password_confirmation ])
  end
end
