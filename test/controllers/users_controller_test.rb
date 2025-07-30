require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "should get account" do
    get users_account_url
    assert_response :success
  end
end
