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
    @user.settings = { "filters" => { "notes" => "archived" } }

    assert_equal "archived", @user.settings[:filters][:notes]
    assert_equal "archived", @user.settings["filters"]["notes"]
  end

  test "default settings should be derived from settings schema" do
    assert_equal User::Settings.defaults(User::Settings::SCHEMA), User::DEFAULT_SETTINGS
  end

  test "get_setting should return nested custom value or default" do
    @user.settings = { "filters" => { "notes" => "archived" } }

    assert_equal "archived", @user.get_setting(:filters, :notes)
    assert_equal User::DEFAULT_SETTINGS[:goals][:weekly_applications], @user.get_setting(:goals, :weekly_applications)
  end

  test "get_setting should return nil for unknown settings" do
    assert_nil @user.get_setting(:unknown_setting)
    assert_nil @user.get_setting(:job_leads_filter)
    assert_nil @user.get_setting(:filters, :bogus)
  end

  test "all_settings should deep merge custom settings over defaults" do
    @user.settings = { goals: { weekly_applications: 3 } }

    settings = @user.all_settings

    assert_equal 3, settings[:goals][:weekly_applications]
    assert_equal User::DEFAULT_SETTINGS[:filters][:job_leads], settings[:filters][:job_leads]
    assert_equal User::DEFAULT_SETTINGS[:archiving][:inactive][:after_days], settings[:archiving][:inactive][:after_days]
  end

  test "update_settings should persist valid nested values and preserve untouched siblings" do
    assert @user.update_settings(
      filters: { job_leads: "active", notes: "archived" },
      layouts: { interviews: "minimal", notes: "list" },
      goals: { weekly_applications: 1001 },
      archiving: { rejected: { enabled: false }, stale: { archive_after_days: 366 } }
    )

    @user.reload
    assert_equal "active", @user.get_setting(:filters, :job_leads)
    assert_equal "archived", @user.get_setting(:filters, :notes)
    assert_equal "minimal", @user.get_setting(:layouts, :interviews)
    assert_equal "list", @user.get_setting(:layouts, :notes)
    assert_equal 1001, @user.get_setting(:goals, :weekly_applications)
    assert_equal false, @user.get_setting(:archiving, :rejected, :enabled)
    assert_equal 366, @user.get_setting(:archiving, :stale, :archive_after_days)
    assert_equal "all", @user.get_setting(:filters, :interviews)
  end

  test "update_settings should ignore invalid payload values while persisting valid siblings" do
    @user.update_settings(
      filters: { job_leads: "active" },
      layouts: { notes: "list" },
      goals: { weekly_applications: 12 },
      archiving: { rejected: { enabled: false } },
      follow_ups: { application_days: 9 }
    )

    @user.update_settings(
      filters: { job_leads: "missing", notes: "archived" },
      layouts: { notes: "masonry" },
      goals: { weekly_applications: "10" },
      archiving: { rejected: { enabled: "false" } },
      follow_ups: { application_days: 9.5 }
    )

    @user.reload
    assert_equal "active", @user.get_setting(:filters, :job_leads)
    assert_equal "archived", @user.get_setting(:filters, :notes)
    assert_equal "list", @user.get_setting(:layouts, :notes)
    assert_equal 12, @user.get_setting(:goals, :weekly_applications)
    assert_equal false, @user.get_setting(:archiving, :rejected, :enabled)
    assert_equal 9, @user.get_setting(:follow_ups, :application_days)
  end

  test "update_settings should drop flat legacy keys unknown keys and unknown nested paths" do
    @user.update_settings(job_leads_filter: "archived", filters: { bogus: "x" }, unknown: { value: "x" })

    @user.reload
    assert_equal({}, @user.settings)
    assert_equal "all", @user.get_setting(:filters, :job_leads)
    assert_nil @user.get_setting(:filters, :bogus)
  end

  test "update_settings should ignore scalar garbage at branch positions without clobbering existing values" do
    @user.update_settings(goals: { weekly_applications: 15 })

    @user.update_settings(goals: "foo")

    assert_equal 15, @user.reload.get_setting(:goals, :weekly_applications)
  end

  test "update_settings should ignore nil leaves" do
    @user.update_settings(goals: { weekly_applications: 15 })

    @user.update_settings(goals: { weekly_applications: nil })

    assert_equal 15, @user.reload.get_setting(:goals, :weekly_applications)
  end

  test "invalid assigned settings should fall back to defaults and not persist" do
    @user.settings = {
      filters: { job_leads: "bogus" },
      layouts: { notes: "masonry" },
      goals: { weekly_applications: "1001" },
      archiving: { stale: { enabled: "true", mark_after_days: 1.5 } }
    }

    @user.save!
    @user.reload

    assert_equal "all", @user.get_setting(:filters, :job_leads)
    assert_equal "grid", @user.get_setting(:layouts, :notes)
    assert_equal 10, @user.get_setting(:goals, :weekly_applications)
    assert_equal true, @user.get_setting(:archiving, :stale, :enabled)
    assert_equal 7, @user.get_setting(:archiving, :stale, :mark_after_days)
    assert_equal({}, @user.settings)
  end

  test "assigned unknown nested settings should be stripped on save" do
    @user.settings = { filters: { bogus: "x", notes: "archived" } }

    @user.save!
    @user.reload

    assert_equal({ "filters" => { "notes" => "archived" } }, @user.settings)
    assert_nil @user.get_setting(:filters, :bogus)
  end

  test "assigned scalar branches should be stripped on save" do
    @user.settings = { goals: 5 }

    @user.save!
    @user.reload

    assert_equal({}, @user.settings)
    assert_equal 10, @user.get_setting(:goals, :weekly_applications)
  end

  test "reset_all_settings should clear custom settings" do
    @user.update_settings(goals: { weekly_applications: 42 })
    @user.reset_all_settings

    assert_equal({}, @user.reload.settings)
    assert_equal User::DEFAULT_SETTINGS[:goals][:weekly_applications], @user.get_setting(:goals, :weekly_applications)
  end

  test "weekly_application_goal_progress should return correct percentage" do
    @user.update_settings(goals: { weekly_applications: 5 })

    # Clear any existing job leads
    @user.job_leads.destroy_all

    3.times do |i|
      create_job_lead(application_url: "https://example.com/jobs/#{i}", applied_at: Time.current)
    end

    create_job_lead(application_url: "https://example.com/jobs/old", applied_at: 1.week.ago)

    assert_equal 60, @user.weekly_application_goal_progress
  end

  test "weekly_application_goal_progress should clamp to 0 if no leads" do
    @user.update_settings(goals: { weekly_applications: 5 })
    @user.job_leads.destroy_all

    assert_equal 0, @user.weekly_application_goal_progress
  end

  test "weekly_application_goal_progress should handle goal of zero gracefully" do
    @user.update_settings(goals: { weekly_applications: 0 })
    @user.job_leads.create!(title: "Example", company: "Example Co.", application_url: "https://example.com/jobs", applied_at: Time.current)

    assert_equal 0, @user.weekly_application_goal_progress
  end

  test "weekly_application_goal_progress should exceed 100 when goal is surpassed" do
    @user.update_settings(goals: { weekly_applications: 2 })
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
