require "test_helper"

class PagesHelperTest < ActionView::TestCase
  include ApplicationHelper
  setup do
    sign_in_as users(:one)
  end

  teardown do
    Current.reset
  end

  test "suggestions render as tiles in a card grid with the cards style" do
    assert_equal "grid grid-cols-1 gap-1.5", suggestion_grid_class_names(1)
    assert_equal "grid grid-cols-1 gap-1.5 @xl:grid-cols-2", suggestion_grid_class_names(2)
    assert_includes suggestion_item_class_names, "bg-neutral-100"
  end

  test "suggestions render as minimal items with the minimal style" do
    Current.user.settings = { appearance: { style: "minimal" } }

    assert_equal "card-list minimal-item-list", suggestion_grid_class_names(1)
    assert_equal "card-grid minimal-item-list", suggestion_grid_class_names(3)
    assert_equal "relative flex flex-col gap-5 minimal-item", suggestion_item_class_names
  end
end
