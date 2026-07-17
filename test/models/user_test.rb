require "test_helper"
require "securerandom"

class UserTest < ActiveSupport::TestCase
  EMAIL = "test@example.com"
  PASSWORD = "Valid123!"

  setup do
    @user = users(:one)
  end

  teardown do
    User.destroy_all
  end

  test "should be valid with valid attributes" do
    assert @user.valid?
  end

  test "should require email" do
    @user.email_address = ""

    assert_not @user.valid?
    assert_includes @user.errors[:email_address], "can't be blank"
  end

  test "should require a valid email" do
    @user.email_address = "not-an-email"

    assert_not @user.valid?
    assert_includes @user.errors[:email_address], "is invalid"
  end

  test "should enforce unique email" do
    @user.save!
    duplicate_user = @user.dup

    assert_not duplicate_user.valid?
    assert_includes duplicate_user.errors[:email_address], "has already been taken"
  end

  test "email should be normalized" do
    mixed_case_email = "  Foo@GmAiL.CoM   "
    @user.email_address = mixed_case_email
    @user.save!

    assert_equal mixed_case_email.strip.downcase, @user.reload.email_address
  end

  test "email alias should read and write email_address" do
    @user.email = "  Alias@Example.COM  "
    @user.save!

    assert_equal "alias@example.com", @user.reload.email_address
    assert_equal @user.email_address, @user.email
  end

  test "name should be normalized" do
    @user.name = "  Example User  "
    @user.save!

    assert_equal "Example User", @user.reload.name
  end

  test "should require password on create" do
    user = build_user(password: "", password_confirmation: "")

    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "should allow update without changing password" do
    @user.name = "Updated Name"

    assert @user.valid?
  end

  test "should require password on update when password confirmation is present" do
    @user.password_confirmation = PASSWORD

    assert_not @user.valid?
    assert_includes @user.errors[:password], "can't be blank"
  end

  test "settings should support indifferent access" do
    @user.settings = { "notes_filter" => "archived" }

    assert_equal "archived", @user.settings[:notes_filter]
    assert_equal "archived", @user.settings["notes_filter"]
  end

  test "get_setting should return custom value or default" do
    @user.settings = { "notes_filter" => "archived" }

    assert_equal "archived", @user.get_setting(:notes_filter)
    assert_equal User::DEFAULT_SETTINGS[:weekly_application_goal], @user.get_setting(:weekly_application_goal)
  end

  test "get_setting should return nil for unknown settings" do
    assert_nil @user.get_setting(:unknown_setting)
  end

  test "all_settings should merge custom settings over defaults" do
    @user.settings = { weekly_application_goal: 3 }

    settings = @user.all_settings

    assert_equal 3, settings[:weekly_application_goal]
    assert_equal User::DEFAULT_SETTINGS[:job_leads_filter], settings[:job_leads_filter]
  end

  test "set_setting should persist a single setting without removing others" do
    @user.set_setting(:notes_filter, "archived")
    @user.set_setting("notes_display", "list")

    @user.reload
    assert_equal "archived", @user.get_setting(:notes_filter)
    assert_equal "list", @user.get_setting(:notes_display)
  end

  test "reset_all_settings should clear custom settings" do
    @user.set_setting(:weekly_application_goal, 42)
    @user.reset_all_settings

    assert_equal({}, @user.reload.settings)
    assert_equal User::DEFAULT_SETTINGS[:weekly_application_goal], @user.get_setting(:weekly_application_goal)
  end

  test "weekly_application_goal_progress should return correct percentage" do
    @user.set_setting(:weekly_application_goal, 5)

    # Clear any existing job leads
    @user.job_leads.destroy_all

    3.times do |i|
      create_job_lead(application_url: "https://example.com/jobs/#{i}", applied_at: Time.current)
    end

    create_job_lead(application_url: "https://example.com/jobs/old", applied_at: 1.week.ago)

    assert_equal 60, @user.weekly_application_goal_progress
  end

  test "weekly_application_goal_progress should clamp to 0 if no leads" do
    @user.set_setting(:weekly_application_goal, 5)
    @user.job_leads.destroy_all

    assert_equal 0, @user.weekly_application_goal_progress
  end

  test "weekly_application_goal_progress should handle goal of zero gracefully" do
    @user.set_setting(:weekly_application_goal, 0)
    @user.job_leads.create!(title: "Example", company: "Example Co.", application_url: "https://example.com/jobs", applied_at: Time.current)

    assert_equal 0, @user.weekly_application_goal_progress
  end

  test "weekly_application_goal_progress should exceed 100 when goal is surpassed" do
    @user.set_setting(:weekly_application_goal, 2)
    @user.job_leads.destroy_all

    3.times do |i|
      create_job_lead(application_url: "https://example.com/surpassed-goal-#{i}", applied_at: Time.current)
    end

    assert_equal 150, @user.weekly_application_goal_progress
  end

  private

  def build_user(attributes = {})
    User.new({
      name: "Test User",
      email_address: "test-#{SecureRandom.hex(8)}@example.com",
      password: PASSWORD,
      password_confirmation: PASSWORD
    }.merge(attributes))
  end
end
