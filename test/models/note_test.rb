require "test_helper"

class NoteTest < ActiveSupport::TestCase
  setup do
    @note = notes(:one)
  end

  teardown do
    Note.destroy_all
  end

  test "should be valid with valid attributes" do
    assert @note.valid?
  end

  test "should require content" do
    @note.content = ""

    assert_not @note.valid?
    assert_includes @note.errors[:content], "can't be blank"
  end

  test "recent includes notes updated within the last seven days" do
    freeze_time

    before_window =   create_note(updated_at: 7.days.ago - 1.second)
    start_of_window = create_note(updated_at: 7.days.ago)
    current =         create_note(updated_at: Time.current)

    recent = Note.recent

    refute_includes recent, before_window
    assert_includes recent, start_of_window
    assert_includes recent, current
  end

  test "recent accepts a custom timeframe" do
    freeze_time

    before_window =              create_note(updated_at: 14.days.ago - 1.second)
    start_of_window =            create_note(updated_at: 14.days.ago)
    only_with_custom_timeframe = create_note(updated_at: 10.days.ago)
    current =                    create_note(updated_at: Time.current)

    recent = Note.recent(14.days)

    refute_includes recent, before_window
    assert_includes recent, start_of_window
    assert_includes recent, only_with_custom_timeframe
    assert_includes recent, current
  end

  test "job_lead should return notable when notable is a job lead" do
    job_lead_note = notes(:one)

    assert_equal job_lead_note.notable, job_lead_note.job_lead
  end

  test "job_lead should return the interview job lead when notable is an interview" do
    interview_note = notes(:two)

    assert_equal interview_note.notable.job_lead, interview_note.job_lead
  end

  test "job_lead should return nil without a notable" do
    note = Note.new

    assert_nil note.job_lead
  end

  test "title should return job lead title and company for job lead notes" do
    job_lead_note = notes(:one)
    job_lead = job_lead_note.notable
    expected_title = "#{job_lead.title} @ #{job_lead.company}"

    assert_equal job_lead_note.title, expected_title
  end

  test "title should return interview title for interview notes" do
    interview_note = notes(:two)
    interview = interview_note.notable
    job_lead = interview.job_lead
    expected_title = "Interview with #{interview.interviewer} - #{job_lead.title} @ #{job_lead.company}"

    assert_equal interview_note.title, expected_title
  end

  test "title should return human model name for other notable types" do
    note = Note.new(user: users(:one), notable: users(:one), content: "User note")

    assert_equal "User", note.title
  end

  private

  def create_note(attributes = {})
    users(:one).notes.create!({
      notable: job_leads(:one),
      content: "Note content"
    }.merge(attributes))
  end
end
