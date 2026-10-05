require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @user = users(:one)
    @user.sessions.delete_all
  end

  test "signing in sends a new login email" do
    assert_enqueued_email_with SessionsMailer, :new_login, args: ->(args) { args.first.user == @user } do
      sign_in
    end
  end

  test "failed sign in keeps the email and explains why" do
    post session_url, params: { email_address: @user.email_address, password: "wrong" }

    assert_response :unprocessable_content
    assert_match "don’t match", flash[:error]
    assert_select "input[name=email_address][value=?]", @user.email_address
    assert_empty @user.sessions.reload
  end

  test "can log out one of your own sessions" do
    sign_in
    other = @user.sessions.create!

    delete session_url(session: other)

    assert_redirected_to security_url
    assert_not Session.exists?(other.id)
  end

  test "cannot log out another user's session" do
    sign_in
    other = users(:two).sessions.create!

    delete session_url(session: other)

    assert_response :not_found
    assert Session.exists?(other.id)
  end

  test "log out all keeps the current session" do
    current = sign_in
    2.times { @user.sessions.create! }
    foreign = users(:two).sessions.create!

    delete destroy_other_sessions_url

    assert_redirected_to security_url
    assert_equal "Terminated 2 sessions.", flash[:notice]
    assert_equal [ current ], @user.sessions.reload.to_a
    assert Session.exists?(foreign.id)
  end

  test "log out inactive sessions only removes sessions older than the mark" do
    current = sign_in
    current.update_columns(updated_at: 2.weeks.ago)
    recent = @user.sessions.create!
    stale = @user.sessions.create!
    stale.update_columns(updated_at: 2.months.ago)

    delete destroy_inactive_sessions_url(since: "1_month")

    assert_redirected_to security_url
    assert_equal "Terminated 1 session inactive for over 1 month.", flash[:notice]
    assert_equal [ current, recent ].sort_by(&:id), @user.sessions.reload.sort_by(&:id)
  end

  test "log out inactive sessions never removes the current session" do
    current = sign_in
    current.update_columns(updated_at: 1.year.ago)

    delete destroy_inactive_sessions_url(since: "6_months")

    assert_equal "No sessions to terminate.", flash[:notice]
    assert Session.exists?(current.id)
  end

  test "log out inactive sessions rejects unknown time ranges" do
    sign_in
    stale = @user.sessions.create!
    stale.update_columns(updated_at: 1.year.ago)

    delete destroy_inactive_sessions_url(since: "1_day")

    assert_redirected_to security_url
    assert_equal "Invalid time range.", flash[:error]
    assert Session.exists?(stale.id)
  end

  private

  def sign_in
    post session_url, params: { email_address: @user.email_address, password: "password" }
    @user.sessions.order(:created_at).last
  end
end
