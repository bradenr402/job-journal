require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "sign up form asks password managers for a new password" do
    get new_registrations_url

    assert_select "input[name='user[password]'][autocomplete=new-password]"
    assert_select "input[name='user[password_confirmation]'][autocomplete=new-password]"
  end

  test "failed sign up shows why and keeps the email" do
    post registrations_url, params: { user: { email_address: "new@example.com", password: "abc", password_confirmation: "abc" } }

    assert_response :unprocessable_content
    assert_select "#error_explanation", /too short/
    assert_select "input[name='user[email_address]'][value=?]", "new@example.com"
  end
end
