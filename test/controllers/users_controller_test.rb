require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "should get account" do
    get account_url
    assert_response :success
  end

  test "should update account" do
    patch account_update_url(@user), params: { user: { email_address: "new@example.com", current_password: "password" } }

    assert_redirected_to edit_account_url
  end

  test "should prevent duplicate emails" do
    patch account_update_url(@user), params: { user: { email_address: "two@example.com", current_password: "password" } }
    assert :unprocessable_content
  end

  test "changing password signs out other sessions" do
    other = @user.sessions.create!
    foreign = users(:two).sessions.create!

    patch account_update_url(@user), params: { user: { password: "new-password", password_confirmation: "new-password", current_password: "password" } }

    assert_redirected_to edit_account_url
    assert_not Session.exists?(other.id)
    assert Session.exists?(Current.session.id)
    assert Session.exists?(foreign.id)
  end

  test "updating without a password change keeps other sessions" do
    other = @user.sessions.create!

    patch account_update_url(@user), params: { user: { name: "New Name", current_password: "password" } }

    assert Session.exists?(other.id)
  end

  test "changing only the name does not require the current password" do
    patch account_update_url(@user), params: { user: { name: "New Name" } }

    assert_redirected_to edit_account_url
    assert_equal "New Name", @user.reload.name
  end

  test "changing the email signs out other sessions and notifies the old address" do
    other = @user.sessions.create!
    old_email = @user.email_address

    assert_enqueued_email_with UsersMailer, :email_changed, args: [ @user, { previous_email: old_email } ] do
      patch account_update_url(@user), params: { user: { email_address: "new@example.com", current_password: "password" } }
    end

    assert_redirected_to edit_account_url
    assert_not Session.exists?(other.id)
  end

  test "changing only the name sends no email" do
    assert_no_enqueued_emails do
      patch account_update_url(@user), params: { user: { name: "Someone" } }
    end
  end

  test "changing the email requires the current password" do
    patch account_update_url(@user), params: { user: { email_address: "new@example.com", current_password: "wrong" } }

    assert_response :unprocessable_content
    assert_not_equal "new@example.com", @user.reload.email_address
  end

  test "changing the password requires the current password" do
    patch account_update_url(@user), params: { user: { password: "new-password", password_confirmation: "new-password" } }

    assert_response :unprocessable_content
    assert @user.reload.authenticate("password")
  end

  test "account page shows stats and links" do
    get account_url

    assert_select "dl dt", 5
    assert_select "a.blanket-link[href=?]", security_path
  end

  test "export page lists download options" do
    get account_export_url

    assert_response :success
    assert_select "a[href=?]", download_account_export_path(format: :json)
    assert_select "a[href=?]", download_account_export_path("job_leads", format: :csv)
  end

  test "downloads a json export" do
    get download_account_export_url(format: :json)

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_match "attachment", response.headers["Content-Disposition"]
    assert_equal @user.email_address, JSON.parse(response.body).dig("account", "email_address")
  end

  test "downloads a csv export" do
    get download_account_export_url("interviews", format: :csv)

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match "jobjournal-interviews-", response.headers["Content-Disposition"]
  end

  test "rejects unknown csv datasets" do
    get download_account_export_url("sessions", format: :csv)

    assert_response :not_found
  end

  test "should delete account" do
    id = @user.id

    delete registrations_url, params: { current_password: "password", confirm_delete: "DELETE" }

    assert_nil User.find_by(id:)
  end

  test "does not delete the account without the password and typed confirmation" do
    [
      {},
      { current_password: "password", confirm_delete: "delete" },
      { current_password: "wrong", confirm_delete: "DELETE" },
      { confirm_delete: "DELETE" }
    ].each do |params|
      delete registrations_url, params: params

      assert_redirected_to edit_account_url
      assert User.exists?(@user.id)
    end
  end
end
