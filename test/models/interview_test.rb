require "test_helper"

class InterviewTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @interview = interviews(:one)
  end

  teardown do
    Interview.destroy_all
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

  test "should require job_lead" do
    @interview.job_lead = nil
    assert_not @interview.valid?
    assert_includes @interview.errors[:job_lead], "must exist"
  end

  test "should enforce maximum lengths" do
    @interview.interviewer = "a" * 256
    assert_not @interview.valid?
    assert_includes @interview.errors[:interviewer], "is too long (maximum is 255 characters)"

    @interview.interviewer = "John Doe"
    @interview.location = "a" * 256
    assert_not @interview.valid?
    assert_includes @interview.errors[:location], "is too long (maximum is 255 characters)"
  end

  test "should allow location to be blank" do
    @interview.location = ""

    assert @interview.valid?
  end

  test "should normalize interviewer and location" do
    @interview.interviewer = "  Jane   Doe  "
    @interview.location = "  Google   Meet  "
    @interview.valid?

    assert_equal "Jane Doe", @interview.interviewer
    assert_equal "Google Meet", @interview.location
  end

  test "should require a valid call_url" do
    @interview.call_url = "not_a_valid_url"

    assert_not @interview.valid?
    assert_includes @interview.errors[:call_url], "is invalid"
  end

  test "should allow call_url to be blank" do
    @interview.call_url = ""

    assert @interview.valid?
  end

  test "should allow rating between 1 and 5" do
    1.upto(5) do |rating|
      @interview.rating = rating
      assert @interview.valid?
    end
  end

  test "should enforce numericality of rating" do
    invalid_ratings = {
      -1 => "must be greater than or equal to 1",
      6 => "must be less than or equal to 5"
    }

    invalid_ratings.each do |rating, error_message|
      @interview.rating = rating
      assert_not @interview.valid?
      assert_includes @interview.errors[:rating], error_message
    end
  end

  test "should allow rating to be nil" do
    @interview.rating = nil

    assert @interview.valid?
  end

  test "should convert zero rating to nil" do
    @interview.rating = 0

    assert @interview.valid?
    assert_nil @interview.rating
  end

  test "upcoming defaults to today through seven days from now" do
    freeze_time

    before_today =   create_interview(scheduled_at: Time.current.beginning_of_day - 1.second)
    start_of_today = create_interview(scheduled_at: Time.current.beginning_of_day)
    end_of_window =  create_interview(scheduled_at: 7.days.from_now)
    after_window =   create_interview(scheduled_at: 7.days.from_now + 1.second)

    upcoming = Interview.upcoming

    refute_includes upcoming, before_today
    assert_includes upcoming, start_of_today
    assert_includes upcoming, end_of_window
    refute_includes upcoming, after_window
  end

  test "upcoming accepts a custom timeframe" do
    freeze_time

    before_today =               create_interview(scheduled_at: Time.current.beginning_of_day - 1.second)
    start_of_today =             create_interview(scheduled_at: Time.current.beginning_of_day)
    only_with_custom_timeframe = create_interview(scheduled_at: 10.days.from_now)
    end_of_window =              create_interview(scheduled_at: 14.days.from_now)
    after_window =               create_interview(scheduled_at: 14.days.from_now + 1.second)

    upcoming = Interview.upcoming(14.days)

    refute_includes upcoming, before_today
    assert_includes upcoming, start_of_today
    assert_includes upcoming, only_with_custom_timeframe
    assert_includes upcoming, end_of_window
    refute_includes upcoming, after_window
  end

  test "recent defaults to the last three days through now" do
    freeze_time

    before_window =   create_interview(scheduled_at: 3.days.ago.beginning_of_day - 1.second)
    start_of_window = create_interview(scheduled_at: 3.days.ago.beginning_of_day)
    current =         create_interview(scheduled_at: Time.current)
    future =          create_interview(scheduled_at: 1.second.from_now)

    recent = Interview.recent

    refute_includes recent, before_window
    assert_includes recent, start_of_window
    assert_includes recent, current
    refute_includes recent, future
  end

  test "recent accepts a custom timeframe" do
    freeze_time

    before_window =              create_interview(scheduled_at: 5.days.ago.beginning_of_day - 1.second)
    start_of_window =            create_interview(scheduled_at: 5.days.ago.beginning_of_day)
    only_with_custom_timeframe = create_interview(scheduled_at: 4.days.ago)
    current =                    create_interview(scheduled_at: Time.current)
    future =                     create_interview(scheduled_at: 1.second.from_now)

    recent = Interview.recent(5.days)

    refute_includes recent, before_window
    assert_includes recent, start_of_window
    assert_includes recent, only_with_custom_timeframe
    assert_includes recent, current
    refute_includes recent, future
  end

  test "future and past should include records scheduled exactly now" do
    freeze_time

    past_interview =    create_interview(scheduled_at: 1.second.ago)
    current_interview = create_interview(scheduled_at: Time.current)
    future_interview =  create_interview(scheduled_at: 1.second.from_now)

    future = Interview.future
    past = Interview.past

    refute_includes future, past_interview
    assert_includes future, current_interview
    assert_includes future, future_interview

    assert_includes past, past_interview
    assert_includes past, current_interview
    refute_includes past, future_interview
  end

  test "future and scheduled predicates should reflect future scheduled_at" do
    freeze_time

    interview = build_interview(scheduled_at: 1.hour.from_now)

    assert_predicate interview, :future?
    assert_predicate interview, :scheduled?
    assert_not interview.past?
    assert_not interview.completed?
  end

  test "past and completed predicates should reflect past scheduled_at" do
    freeze_time

    interview = build_interview(scheduled_at: 1.hour.ago)

    assert_predicate interview, :past?
    assert_predicate interview, :completed?
    assert_not interview.future?
    assert_not interview.scheduled?
  end

  test "time predicates should be false at the current time boundary" do
    freeze_time

    interview = build_interview(scheduled_at: Time.current)

    assert_not interview.future?
    assert_not interview.scheduled?
    assert_not interview.past?
    assert_not interview.completed?
  end

  test "user should delegate to job_lead" do
    assert_equal @interview.job_lead.user, @interview.user
  end

  test "title should include interviewer for persisted interviews" do
    expected_title = "Interview with #{@interview.interviewer} - #{@interview.job_lead.title} @ #{@interview.job_lead.company}"

    assert_equal expected_title, @interview.title
  end

  test "title should omit interviewer for new interviews" do
    interview = build_interview(interviewer: "Sarah Chen")
    expected_title = "Interview - #{interview.job_lead.title} @ #{interview.job_lead.company}"

    assert_equal expected_title, interview.title
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

  test "calendar event should have JobJournal URL before notes in description" do
    note = @interview.notes.create!(user: @user, content: "Prepare questions about the team")

    event = @interview.calendar_event(calendar_request)

    assert_equal "JobJournal: #{interview_url}\n\n#{note.content}", event.description.to_s
  end

  test "calendar event should omit blank optional properties" do
    @interview.update!(location: "", call_url: "")

    event = @interview.calendar_event(calendar_request)

    assert_empty event.location.to_s
    assert_empty event.url.to_s
  end

  test "calendar event description should omit blank notes section" do
    @interview.notes.destroy_all

    event = @interview.calendar_event(calendar_request)

    assert_equal "JobJournal: #{interview_url}", event.description.to_s
  end

  private

  def build_interview(attributes = {})
    Interview.new({
      job_lead: job_leads(:one),
      interviewer: "Taylor Smith",
      scheduled_at: Time.current
    }.merge(attributes))
  end

  def create_interview(attributes = {})
    build_interview(attributes).tap(&:save!)
  end

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
