require 'test_helper'

class SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'should get search' do
    get search_url
    assert_response :success
  end
end
