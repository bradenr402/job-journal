class UsersController < ApplicationController
  def account
    @user = Current.user
    @sessions = @user.sessions.order(updated_at: :desc)
  end

  def edit
    @user = Current.user
  end

  def update
    @user = Current.user

    current_password = params[:user][:current_password]

    if @user.authenticate(current_password)
      if @user.update(user_params)
        redirect_to edit_account_path, success: 'Account updated successfully.'
      else
        render :edit, status: :unprocessable_entity, error: @user.errors.full_messages.join(', ')
      end
    else
      @user.errors.add(:current_password, 'is incorrect')
      render :edit, status: :unprocessable_entity, error: 'Current password is incorrect.'
    end
  end

  private

  def user_params
    params.expect(user: [ :name, :email_address, :password, :password_confirmation ])
  end
end
