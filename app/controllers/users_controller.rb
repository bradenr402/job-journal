class UsersController < ApplicationController
  rate_limit to: 10, within: 1.minute, only: :download_export, by: -> { Current.user.id },
    with: -> { redirect_to account_export_path, alert: "Too many downloads. Try again in a minute." }

  def account
    @user = Current.user
  end

  def export
    @export_counts = {
      job_leads: Current.user.job_leads.count,
      interviews: Current.user.interviews.count,
      notes: Current.user.notes.count
    }
  end

  def download_export
    export = AccountExport.new(Current.user)
    date = Date.current.iso8601

    respond_to do |format|
      format.json do
        send_data export.to_json, filename: "jobjournal-export-#{date}.json", type: :json
      end
      format.csv do
        dataset = params.expect(:dataset)
        raise ActionController::RoutingError, "Unknown export" unless dataset.in?(AccountExport::DATASETS)

        send_data export.to_csv(dataset), filename: "jobjournal-#{dataset.dasherize}-#{date}.csv", type: :csv
      end
    end
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
