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

  test "should delete account" do
    id = @user.id

    delete registrations_url

    assert_nil User.find_by(id:)
  end
end
