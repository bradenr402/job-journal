require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  setup do
    Current.reset
  end

  teardown do
    Current.reset
  end

  test "user should return nil without a session" do
    assert_nil Current.user
  end

  test "user should delegate to the current session user" do
    Current.session = sessions(:one)

    assert_equal users(:one), Current.user
  end
end
