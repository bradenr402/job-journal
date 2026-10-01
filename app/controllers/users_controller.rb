class UsersController < ApplicationController
  def account
    @user = Current.user
  end

  def edit
    @user = Current.user
  end

  def update
    @user = Current.user

    current_password = params[:user][:current_password]

    if @user.authenticate(current_password)
      if @user.update(user_params)
        message = "Account updated successfully."

        if @user.saved_change_to_password_digest?
          terminate_sessions @user.sessions.where.not(id: Current.session.id)
          message = "Account updated successfully. You’ve been signed out of all other sessions."
        end

        redirect_to edit_account_path, success: message
      else
        render :edit, status: :unprocessable_content, error: @user.errors.full_messages.join(", ")
      end
    else
      @user.errors.add(:current_password, "is incorrect")
      render :edit, status: :unprocessable_content, error: "Current password is incorrect."
    end
  end

  private

  def user_params
    params.expect(user: [ :name, :email_address, :password, :password_confirmation ])
  end
end
