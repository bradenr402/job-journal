require "test_helper"

class LandingDemo::RecordBuilderTest < ActiveSupport::TestCase
  setup do
    @builder = LandingDemo::RecordBuilder.new
    @user = users(:one)
    @lead = job_leads(:one)
  end

  teardown do
    User.destroy_all
    JobLead.destroy_all
  end

  test "lead should build an unsaved job lead with demo status methods" do
    status_at = Time.zone.local(2026, 7, 11, 14, 5)

    lead = @builder.lead(
      id: 1001,
      user: @user,
      title: "Senior Software Engineer",
      company: "Stripe",
      application_url: "https://stripe.com/jobs/1234",
      status: "interview",
      status_at:
    )

    assert_predicate lead, :new_record?
    assert_equal 1001, lead.id
    assert_equal @user, lead.user
    assert_equal "Senior Software Engineer", lead.title
    assert_equal "interview", lead.status
    assert_equal status_at, lead.latest_status_at
  end

  test "lead should preload tags and notes for demo partials" do
    lead = @builder.lead(
      id: 1001,
      user: @user,
      title: "Senior Software Engineer",
      company: "Stripe",
      application_url: "https://stripe.com/jobs/1234",
      status: "interview",
      tags: [ "remote", "dream job" ],
      notes_count: 2
    )

    assert_predicate lead.association(:tags), :loaded?
    assert_predicate lead.association(:notes), :loaded?
    assert_equal [ "remote", "dream job" ], lead.tags.map(&:name)
    assert_equal [ 14010, 14011 ], lead.tags.map(&:id)
    assert_equal [ 15010, 15011 ], lead.notes.map(&:id)
  end

  test "lead should default missing tags and notes to empty loaded associations" do
    lead = @builder.lead(
      id: 1001,
      user: @user,
      title: "Senior Software Engineer",
      company: "Stripe",
      application_url: "https://stripe.com/jobs/1234",
      status: "lead"
    )

    assert_predicate lead.association(:tags), :loaded?
    assert_predicate lead.association(:notes), :loaded?
    assert_empty lead.tags
    assert_empty lead.notes
  end

  test "lead should require explicit status" do
    assert_raises(KeyError) do
      @builder.lead(
        id: 1001,
        user: @user,
        title: "Senior Software Engineer",
        company: "Stripe",
        application_url: "https://stripe.com/jobs/1234"
      )
    end
  end

  test "interview should build an unsaved interview and preload notes" do
    interview = @builder.interview(
      id: 2001,
      job_lead: @lead,
      interviewer: "Sarah Chen",
      scheduled_at: Time.zone.local(2026, 7, 18, 14),
      location: "Google Meet",
      notes_count: 3
    )

    assert_predicate interview, :new_record?
    assert_equal 2001, interview.id
    assert_equal @lead, interview.job_lead
    assert_equal "Sarah Chen", interview.interviewer
    assert_equal "Google Meet", interview.location
    assert_predicate interview.association(:notes), :loaded?
    assert_equal [ 26010, 26011, 26012 ], interview.notes.map(&:id)
  end

  test "interview should default missing notes_count to empty loaded notes" do
    interview = @builder.interview(
      id: 2001,
      job_lead: @lead,
      interviewer: "Sarah Chen",
      scheduled_at: Time.zone.local(2026, 7, 18, 14),
      location: "Google Meet"
    )

    assert_predicate interview.association(:notes), :loaded?
    assert_empty interview.notes
  end
end
