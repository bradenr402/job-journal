require 'test_helper'

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'should get account' do
    get account_url
    assert_response :success
  end

  test 'should update account' do
    patch account_update_url(@user), params: { user: { email_address: 'new@example.com', current_password: 'password' } }

    assert_redirected_to edit_account_url
  end

  test 'should prevent duplicate emails' do
    patch account_update_url(@user), params: { user: { email_address: 'two@example.com', current_password: 'password' } }
    assert :unprocessable_entity
  end
end
