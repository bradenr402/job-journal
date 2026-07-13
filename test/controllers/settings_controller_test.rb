require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "should get edit" do
    get settings_url
    assert_response :success
  end

  test "should get edit with a tab param" do
    get settings_url(tab: "auto_archiving")
    assert_response :success
  end

  test "should fall back to default tab for an invalid tab param" do
    get settings_url(tab: "bogus")
    assert_response :success
  end

  test "should update only submitted settings without clobbering others" do
    @user.set_setting(:notes_filter, "archived")

    patch settings_url(tab: "goals"), params: { weekly_application_goal: "15" }

    assert_redirected_to settings_path(tab: "goals")
    @user.reload
    assert_equal 15, @user.get_setting(:weekly_application_goal)
    assert_equal "archived", @user.get_setting(:notes_filter)
  end

  test "should redirect preserving the submitted tab" do
    patch settings_url(tab: "follow_ups"), params: { application_follow_up_days: "9" }

    assert_redirected_to settings_path(tab: "follow_ups")
    assert_equal 9, @user.reload.get_setting(:application_follow_up_days)
  end

  test "should reset settings and preserve tab" do
    @user.set_setting(:weekly_application_goal, 42)

    patch reset_settings_url(tab: "danger_zone")

    assert_redirected_to settings_path(tab: "danger_zone")
    assert_equal User::DEFAULT_SETTINGS[:weekly_application_goal], @user.reload.get_setting(:weekly_application_goal)
  end
end
