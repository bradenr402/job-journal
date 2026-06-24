require "test_helper"

class Rails::PwaControllerTest < ActionDispatch::IntegrationTest
  test "manifest is publicly accessible" do
    get pwa_manifest_url(format: :json)

    assert_response :success
  end

  test "service worker is publicly accessible" do
    get pwa_service_worker_url(format: :js)

    assert_response :success
  end
end
