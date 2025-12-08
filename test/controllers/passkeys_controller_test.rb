require 'test_helper'

class PasskeysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @passkey = passkeys(:one)
  end

  test "should destroy passkey belonging to current user" do
    assert_difference('Passkey.count', -1) do
      delete passkey_path(@passkey)
    end
    assert_redirected_to security_path
  end

  test "should not destroy other user's passkey" do
    other_passkey = passkeys(:three)
    
    # In test environment, Rails will raise the exception which we can catch
    # In production, it would render a 404 page
    delete passkey_path(other_passkey)
    
    # Should get a 404 response
    assert_response :not_found
    
    # Verify the passkey still exists
    assert Passkey.exists?(other_passkey.id)
  end

  test "should respond with turbo stream on destroy" do
    delete passkey_path(@passkey), as: :turbo_stream
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
  end

  test "should get challenge_create" do
    post challenge_create_passkeys_path
    assert_response :success
    assert_not_nil session[:webauthn_registration_challenge]
    assert_not_nil JSON.parse(response.body)["challenge"]
  end

  test "should get challenge_authenticate" do
    post challenge_authenticate_passkeys_path
    assert_response :success
    assert_not_nil session[:webauthn_authentication_challenge]
    assert_not_nil JSON.parse(response.body)["challenge"]
  end
end
