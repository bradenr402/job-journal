require "test_helper"

class ApplicationRecordTest < ActiveSupport::TestCase
  test "edited? should be false for a new record without timestamps" do
    assert_not Note.new.edited?
  end

  test "edited? should be false when timestamps are equal" do
    note = notes(:one)
    timestamp = Time.current
    note.created_at = timestamp
    note.updated_at = timestamp

    assert_not note.edited?
  end

  test "edited? should be true when updated after creation" do
    note = notes(:one)
    note.created_at = 2.days.ago
    note.updated_at = 1.day.ago

    assert note.edited?
  end
end
