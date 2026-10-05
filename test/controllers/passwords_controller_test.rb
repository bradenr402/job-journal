require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  test "requesting a reset for a known email sends instructions and shows the check email page" do
    assert_enqueued_email_with PasswordsMailer, :reset, args: [ users(:one) ] do
      post passwords_url, params: { email_address: users(:one).email_address }
    end

    assert_redirected_to sent_passwords_url
    follow_redirect!
    assert_select "h1", "Check your email"
    assert_select "strong", "o•••@example.com"
  end

  test "requesting a reset for an unknown email looks the same but sends nothing" do
    assert_no_enqueued_emails do
      post passwords_url, params: { email_address: "nobody@example.com" }
    end

    assert_redirected_to sent_passwords_url
  end

  test "resetting a password signs out every other session and signs you in" do
    user = users(:one)
    old_sessions = 2.times.map { user.sessions.create! }

    patch password_url(user.password_reset_token), params: { password: "new-password", password_confirmation: "new-password" }

    assert_redirected_to dashboard_url
    assert_equal 1, user.sessions.reload.count
    assert_not old_sessions.any? { Session.exists?(it.id) }
  end

  test "a reset with a too-short password explains why" do
    user = users(:one)

    patch password_url(user.password_reset_token), params: { password: "abc", password_confirmation: "abc" }

    assert_response :unprocessable_content
    assert_select "#error_explanation", /too short/
  end

  test "a failed reset keeps sessions" do
    user = users(:one)
    session = user.sessions.create!

    patch password_url(user.password_reset_token), params: { password: "new-password", password_confirmation: "mismatch" }

    assert Session.exists?(session.id)
  end

  test "an invalid reset link explains what happened" do
    get edit_password_url("invalid")

    assert_redirected_to new_password_url
    assert_match "invalid or has expired", flash[:error]
  end
end
