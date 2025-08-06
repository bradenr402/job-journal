require 'test_helper'

class UserTest < ActiveSupport::TestCase
  EMAIL = 'test@example.com'
  PASSWORD = 'Valid#123'

  def setup
    @user = users(:one)
  end

  test 'should be valid with valid attributes' do
    assert @user.valid?
  end

  test 'should require email' do
    @user.email_address = ''
    assert_not @user.valid?
    assert_includes @user.errors[:email_address], "can't be blank"
  end

  test 'should enforce unique email' do
    @user.save!
    duplicate_user = @user.dup
    assert_not duplicate_user.valid?
    assert_includes duplicate_user.errors[:email_address], 'has already been taken'
  end

  test 'email should be normalized' do
    mixed_case_email = '  Foo@GmAiL.CoM   '
    @user.email_address = mixed_case_email
    @user.save!
    assert_equal mixed_case_email.strip.downcase, @user.reload.email_address
  end

  test 'weekly_application_goal_progress should return correct percentage' do
    @user.set_setting(:weekly_application_goal, 5)

    # Clear any existing job leads
    @user.job_leads.destroy_all

    3.times do |i|
      @user.job_leads.create!(title: 'Example', company: 'Example Co.', application_url: "https://example.com/jobs/#{i}", applied_at: Time.current)
    end

    @user.job_leads.create!(title: 'Example', company: 'Example Co.', application_url: 'https://example.com/jobs', applied_at: 1.week.ago)

    assert_equal 60, @user.weekly_application_goal_progress
  end

  test 'weekly_application_goal_progress should clamp to 0 if no leads' do
    @user.set_setting(:weekly_application_goal, 5)
    @user.job_leads.destroy_all

    assert_equal 0, @user.weekly_application_goal_progress
  end

  test 'weekly_application_goal_progress should handle goal of zero gracefully' do
    @user.set_setting(:weekly_application_goal, 0)
    @user.job_leads.create!(title: 'Example', company: 'Example Co.', application_url: 'https://example.com/jobs', applied_at: Time.current)

    assert_equal 0, @user.weekly_application_goal_progress
  end
end
