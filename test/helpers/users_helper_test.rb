require "test_helper"

class UsersHelperTest < ActionView::TestCase
  test "initials come from the first and last name" do
    assert_equal "AL", user_initials(User.new(name: "Ada King Lovelace", email_address: "ada@example.com"))
    assert_equal "A", user_initials(User.new(name: "Ada", email_address: "ada@example.com"))
  end

  test "initials fall back to the email address" do
    assert_equal "J", user_initials(User.new(email_address: "jane.doe@example.com"))
  end
end
