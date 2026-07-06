require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get landing page when not signed in" do
    get root_url
    assert_response :success
  end

  test "should get landing page when signed in" do
    sign_in_as users(:one)
    get root_url
    assert_response :success
  end

  test "should get dashboard when signed in" do
    sign_in_as users(:one)
    get dashboard_url
    assert_response :success
  end

  test "should redirect to sign in when accessing dashboard unauthenticated" do
    get dashboard_url
    assert_redirected_to new_session_url
  end

  test "should embed icons JSON" do
    sign_in_as users(:one)
    get dashboard_url

    match = response.body.match(/window\.JobJournal\.icons\s*=\s*(?<icons>\{.*\});/m)
    assert match, "Expected window.JobJournal.icons assignment"

    icons = JSON.parse match[:icons]

    assert_equal icons, JOB_JOURNAL_ICONS.as_json, "Expected embedded icons JSON to match JOB_JOURNAL_ICONS"
  end
end
