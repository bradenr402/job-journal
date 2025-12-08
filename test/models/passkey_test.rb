require 'test_helper'

class PasskeyTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @passkey = Passkey.new(
      user: @user,
      public_key: "test_public_key",
      name: "Test Passkey",
      sign_count: 0
    )
  end

  test "should be valid with valid attributes" do
    assert @passkey.valid?
  end

  test "should require user" do
    @passkey.user = nil
    assert_not @passkey.valid?
    assert_includes @passkey.errors[:user], "must exist"
  end

  test "should require public_key" do
    @passkey.public_key = nil
    assert_not @passkey.valid?
    assert_includes @passkey.errors[:public_key], "can't be blank"
  end

  test "should require name" do
    @passkey.name = nil
    assert_not @passkey.valid?
    assert_includes @passkey.errors[:name], "can't be blank"
  end

  test "should require sign_count" do
    @passkey.sign_count = nil
    assert_not @passkey.valid?
    assert_includes @passkey.errors[:sign_count], "can't be blank"
  end

  test "should generate identifier on create" do
    assert_nil @passkey.identifier
    @passkey.save!
    assert_not_nil @passkey.identifier
    assert @passkey.identifier.length > 0
  end

  test "should enforce unique identifier" do
    @passkey.save!
    duplicate = @passkey.dup
    duplicate.identifier = @passkey.identifier
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:identifier], "has already been taken"
  end

  test "should belong to user" do
    @passkey.save!
    assert_equal @user, @passkey.user
  end

  test "should update last_used_at with touch_last_used" do
    @passkey.save!
    original_time = @passkey.last_used_at
    
    travel 1.hour do
      @passkey.touch_last_used
      @passkey.reload
      assert_not_equal original_time, @passkey.last_used_at
      assert @passkey.last_used_at > 30.minutes.ago
    end
  end

  test "should update sign_count" do
    @passkey.save!
    assert_equal 0, @passkey.sign_count
    
    @passkey.update_sign_count(5)
    @passkey.reload
    assert_equal 5, @passkey.sign_count
  end

  test "should order by recent scope" do
    # Clear existing passkeys for clean test
    @user.passkeys.destroy_all
    
    old_passkey = Passkey.create!(
      user: @user,
      public_key: "old_key",
      name: "Old Passkey",
      sign_count: 0,
      last_used_at: 1.week.ago
    )
    
    new_passkey = Passkey.create!(
      user: @user,
      public_key: "new_key",
      name: "New Passkey",
      sign_count: 0,
      last_used_at: 1.hour.ago
    )
    
    passkeys = @user.passkeys.recent
    assert_equal new_passkey, passkeys.first
    assert_equal old_passkey, passkeys.last
  end
end
