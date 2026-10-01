require "test_helper"

class SessionTest < ActiveSupport::TestCase
  setup do
    @session = users(:one).sessions.create!(ip_address: "1.1.1.1")
  end

  test "inactive_since only returns sessions older than the mark" do
    stale = users(:one).sessions.create!
    stale.update_columns(updated_at: 2.weeks.ago)

    assert_equal [ stale ], Session.inactive_since("1_week").to_a
  end
end
