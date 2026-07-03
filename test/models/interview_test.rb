require "test_helper"

class InterviewTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @interview = interviews(:one)
  end

  test "should be valid with valid attributes" do
    assert @interview.valid?
  end

  test "should require interviewer" do
    @interview.interviewer = ""
    assert_not @interview.valid?
    assert_includes @interview.errors[:interviewer], "can't be blank"
  end

  test "should require scheduled_at" do
    @interview.scheduled_at = ""
    assert_not @interview.valid?
    assert_includes @interview.errors[:scheduled_at], "can't be blank"
  end

  test "should require a valid call_url" do
    @interview.call_url = "not_a_valid_url"
    assert_not @interview.valid?
    assert_includes @interview.errors[:call_url], "is invalid"
  end

  test "should enforce numericality of rating" do
    @interview.rating = -1

    assert_not @interview.valid?
    assert_includes @interview.errors[:rating], "must be greater than or equal to 1"

    @interview.rating = 6

    assert_not @interview.valid?
    assert_includes @interview.errors[:rating], "must be less than or equal to 5"
  end

  test "calendar event should use interview attributes" do
    event = @interview.calendar_event(calendar_request)

    assert_equal @interview.scheduled_at.to_i, event.dtstart.to_time.to_i
    assert_equal @interview.scheduled_at.advance(hours: 1).to_i, event.dtend.to_time.to_i
    assert_equal @interview.title, event.summary.to_s
    assert_equal @interview.location, event.location.to_s
    assert_equal @interview.call_url, event.url.to_s
    assert_equal "interview-#{@interview.id}@www.example.com", event.uid.to_s
  end

  test "calendar event shouldl have JobJournal URL before notes in description" do
    note = @interview.notes.create!(user: @user, content: "Prepare questions about the team")

    event = @interview.calendar_event(calendar_request)

    assert_equal "JobJournal: #{interview_url}\n\n#{note.content}", event.description.to_s
  end

  private

  def calendar_request
    ActionDispatch::Request.new(Rack::MockRequest.env_for("http://www.example.com/interviews/#{@interview.id}/add_to_calendar"))
  end

  def interview_url
    Rails.application.routes.url_helpers.interview_url(
      @interview,
      Rails.application.config.action_mailer.default_url_options
    )
  end
end
