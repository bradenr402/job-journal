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

    delete registrations_url

    assert_nil User.find_by(id:)
  end
end
