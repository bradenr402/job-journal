require "application_system_test_case"

class AuthenticationTest < ApplicationSystemTestCase
  test "should sign up and land on the dashboard" do
    visit new_registrations_url
    fill_in "Email Address", with: "new@example.com"
    fill_in "Password", with: "secret-password"
    fill_in "Confirm Password", with: "secret-password"
    click_on "Create Account"

    assert_current_path dashboard_path
  end

  test "should keep the email after a failed sign in" do
    visit new_session_url
    fill_in "Email Address", with: users(:one).email_address
    fill_in "Password", with: "wrong"
    click_on "Sign In"

    assert_text "don’t match"
    assert_field "Email Address", with: users(:one).email_address
  end

  test "should carry the email to the forgot password page and confirm the request" do
    visit new_session_url
    fill_in "Email Address", with: users(:one).email_address
    click_on "Forgot password?"

    assert_field "Email Address", with: users(:one).email_address
    click_on "Send Reset Link"

    assert_selector "h1", text: "Check your email"
    assert_text "o•••@example.com"
  end

  test "should reset the password and sign in" do
    visit edit_password_url(users(:one).password_reset_token)
    fill_in "New Password", with: "brand-new-password"
    fill_in "Confirm New Password", with: "brand-new-password"
    click_on "Save and Sign In"

    assert_current_path dashboard_path
    assert_text "Password updated"
  end
end
