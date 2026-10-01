require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  test "resetting a password signs out every session" do
    user = users(:one)
    2.times { user.sessions.create! }

    patch password_url(user.password_reset_token), params: { password: "new-password", password_confirmation: "new-password" }

    assert_redirected_to new_session_url
    assert_empty user.sessions.reload
  end

  test "a reset with a too-short password explains why" do
    user = users(:one)

    patch password_url(user.password_reset_token), params: { password: "abc", password_confirmation: "abc" }

    assert_match "too short", flash[:alert]
  end

  test "a failed reset keeps sessions" do
    user = users(:one)
    session = user.sessions.create!

    patch password_url(user.password_reset_token), params: { password: "new-password", password_confirmation: "mismatch" }

    assert Session.exists?(session.id)
  end
end
