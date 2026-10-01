require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.sessions.delete_all
  end

  test "can log out one of your own sessions" do
    sign_in
    other = @user.sessions.create!

    delete session_url(session: other)

    assert_redirected_to account_url
    assert_not Session.exists?(other.id)
  end

  test "cannot log out another user's session" do
    sign_in
    other = users(:two).sessions.create!

    delete session_url(session: other)

    assert_response :not_found
    assert Session.exists?(other.id)
  end

  private

  def sign_in
    post session_url, params: { email_address: @user.email_address, password: "password" }
    @user.sessions.order(:created_at).last
  end
end
