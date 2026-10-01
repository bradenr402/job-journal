require "test_helper"

class SessionTest < ActiveSupport::TestCase
  setup do
    @session = users(:one).sessions.create!(ip_address: "1.1.1.1")
  end

  test "record_activity skips the write within the throttle window" do
    travel 1.minute do
      assert_no_changes -> { @session.reload.updated_at } do
        @session.record_activity(ip_address: "1.1.1.1")
      end
    end
  end

  test "record_activity updates last seen after the throttle window" do
    travel Session::ACTIVITY_THROTTLE + 1.minute do
      assert_changes -> { @session.reload.updated_at } do
        @session.record_activity(ip_address: "1.1.1.1")
      end
    end
  end

  test "record_activity saves a changed IP address immediately" do
    @session.record_activity(ip_address: "2.2.2.2")

    assert_equal "2.2.2.2", @session.reload.ip_address
  end

  test "inactive_since only returns sessions older than the mark" do
    stale = users(:one).sessions.create!
    stale.update_columns(updated_at: 2.weeks.ago)

    assert_equal [ stale ], Session.inactive_since("1_week").to_a
  end
end
