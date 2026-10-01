require "test_helper"

class DeviceInfoTest < ActiveSupport::TestCase
  MAC_CHROME = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
  IPHONE = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
  IPAD = "Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"

  test "detects desktop browsers" do
    device = DeviceInfo.new(MAC_CHROME)

    assert_equal [ "Desktop", "Mac" ], device.label
    assert_equal "Chrome", device.browser
    assert_equal "computer", device.icon_name
  end

  test "detects smartphones" do
    device = DeviceInfo.new(IPHONE)

    assert_equal [ "Smartphone", "iOS" ], device.label
    assert_equal "smartphone", device.icon_name
  end

  test "detects tablets" do
    device = DeviceInfo.new(IPAD)

    assert_equal "Tablet", device.device_type
    assert_equal "tablet", device.icon_name
  end

  test "falls back when the user agent is missing" do
    device = DeviceInfo.new(nil)

    assert_equal [ "Unknown device" ], device.label
    assert_equal "Unknown", device.browser
    assert_equal "computer", device.icon_name
  end
end
