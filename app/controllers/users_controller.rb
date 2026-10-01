class UsersController < ApplicationController
  rate_limit to: 10, within: 1.minute, only: :download_export, by: -> { Current.user.id },
    with: -> { redirect_to account_export_path, alert: "Too many downloads. Try again in a minute." }

  def account
    @user = Current.user
    job_leads = @user.job_leads

    # SQLite returns MIN/MAX of datetimes as strings, so they're parsed below.
    total, applications, offers, @archived_count, started_at, hired_at = job_leads.pick(
      Arel.sql("COUNT(*)"),
      Arel.sql("COUNT(applied_at)"),
      Arel.sql("COUNT(CASE WHEN offer_amount IS NOT NULL OR offer_at IS NOT NULL THEN 1 END)"),
      Arel.sql("COUNT(archived_at)"),
      Arel.sql("MIN(created_at)"),
      Arel.sql("MAX(accepted_at)")
    )

    @stats = {
      job_leads: total,
      applications:,
      interviews: @user.interviews.count,
      offers:,
      notes: @user.notes.count
    }
    @tags_count = @user.tags.count
    @sessions_count = @user.sessions.count

    started_at = Time.zone.parse(started_at) if started_at
    @hired_at = Time.zone.parse(hired_at) if hired_at
    @search_days = ((@hired_at || Time.current).to_date - started_at.to_date).to_i if started_at
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

    # Check against the saved password before assigning a new one.
    password_confirmed = @user.authenticate(params[:user][:current_password].to_s)

    @user.assign_attributes(user_params)
    changing_credentials = @user.will_save_change_to_email_address? || user_params[:password].present?

    if changing_credentials && !password_confirmed
      @user.errors.add(:current_password, "is incorrect")
      render :edit, status: :unprocessable_content
    elsif @user.save
      message = "Account updated successfully."

      if @user.saved_change_to_password_digest? || @user.saved_change_to_email_address?
        terminate_sessions @user.sessions.where.not(id: Current.session.id)
        message = "Account updated successfully. You’ve been signed out of all other sessions."
      end

      if @user.saved_change_to_email_address?
        UsersMailer.email_changed(@user, previous_email: @user.email_address_before_last_save).deliver_later
      end

      redirect_to edit_account_path, success: message
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def user_params
    params.expect(user: [ :name, :email_address, :password, :password_confirmation ])
  end
end
