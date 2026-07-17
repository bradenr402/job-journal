require "test_helper"

class LandingDemoTest < ActiveSupport::TestCase
   setup do
    @demo = LandingDemo.new
  end

  test "exposes all landing page demo data from one object" do
    assert_equal "Demo User", @demo.user.name
    assert_equal 0, @demo.user.id
    assert_predicate @demo.user, :new_record?
    assert_equal %w[Stripe Notion Vercel Shopify], @demo.leads.map(&:company)
    assert_equal [ "interview", "applied", "offer", "lead" ], @demo.leads.map(&:status)
    assert_equal 2, @demo.interviews.size
    assert_equal 6, @demo.notes.size

    assert_equal({ count: 12, change: "+4 from last week" }, @demo.job_lead_stats)
    assert_equal({ count: 7, change: "+3 from last week", goal: 10 }, @demo.application_stats)
    assert_equal({ count: 3, change: "+1 from last week", average_rating: 4.0 }, @demo.interview_stats)
    assert_equal [ "remote", "hybrid", "referral", "dream job", "series-b", "priority" ], @demo.top_tags
  end

  test "preloads demo associations for partials" do
    lead = @demo.leads.first
    assert_predicate lead.association(:tags), :loaded?
    assert_predicate lead.association(:notes), :loaded?
    assert_equal [ "remote", "dream job" ], lead.tags.map(&:name)
    assert_equal 5, lead.notes.size

    interview = @demo.interviews.first
    assert_predicate interview.association(:notes), :loaded?
    assert_equal 3, interview.notes.size
  end

  test "provides source insight data in the shape expected by the sources partial" do
    sources = @demo.sources

    assert_equal [ "Referral", "Company Website", "LinkedIn", "Indeed" ], sources.keys
    assert_equal(
      {
        lead_count: 4,
        interview_count: 2,
        offer_count: 0,
        accepted_count: 0,
        conversion_rate: 0.5
      },
      sources.fetch("Referral")
    )
  end

  test "leads should be unsaved records for the demo user with materialized timestamps" do
    freeze_time

    lead = @demo.leads.first

    assert_predicate lead, :new_record?
    assert_same @demo.user, lead.user
    assert_equal 1001, lead.id
    assert_equal "Senior Software Engineer", lead.title
    assert_equal "https://stripe.com/jobs/1234", lead.application_url
    assert_equal 10.days.ago + 9.hours, lead.applied_at
    assert_equal 2.days.ago + 11.hours + 42.minutes, lead.updated_at
    assert_equal 5.days.ago + 14.hours + 5.minutes, lead.latest_status_at
  end

  test "interviews should be linked to demo leads and materialize optional attributes" do
    freeze_time

    upcoming_interview, completed_interview = @demo.interviews

    assert_same @demo.leads.first, upcoming_interview.job_lead
    assert_equal "Sarah Chen", upcoming_interview.interviewer
    assert_equal 2.days.from_now + 14.hours, upcoming_interview.scheduled_at
    assert_nil upcoming_interview.rating

    assert_same @demo.leads.second, completed_interview.job_lead
    assert_equal "James Park", completed_interview.interviewer
    assert_equal 4, completed_interview.rating
  end

  test "notes should be linked to demo records and materialize dynamic content" do
    freeze_time

    lead_note = @demo.notes.first
    offer_note = @demo.notes.third
    interview_note = @demo.notes.fifth

    assert_same @demo.user, lead_note.user
    assert_same @demo.leads.first, lead_note.notable
    assert_same @demo.leads.third, offer_note.notable
    assert_includes offer_note.content, 10.days.from_now.strftime("%B %e")
    assert_same @demo.interviews.first, interview_note.notable
  end

  test "suggestions should materialize timestamp lambdas without building records" do
    freeze_time

    suggestions = @demo.suggestions

    assert_equal [ "Staff Frontend Developer", "Senior Software Engineer" ], suggestions.map { _1.fetch(:title) }
    assert_equal [ "applied", "interview" ], suggestions.map { _1.fetch(:status) }
    assert_equal 8.days.ago, suggestions.first.fetch(:status_at)
    assert_kind_of Time, suggestions.second.fetch(:status_at)
  end

  test "stale_leads should expose unsaved lead records with lead status" do
    freeze_time

    stale_leads = @demo.stale_leads

    assert_equal %w[Shopify OpenAI], stale_leads.map(&:company)
    assert_equal [ "lead", "lead" ], stale_leads.map(&:status)
    assert stale_leads.all?(&:new_record?)
    assert_equal 19.days.ago + 4.hours + 1.minute, stale_leads.first.created_at
  end

  test "custom record builder should receive materialized lead and interview attributes" do
    freeze_time

    builder = RecordingRecordBuilder.new
    demo = LandingDemo.new(record_builder: builder)

    demo.interviews

    first_lead_attributes = builder.lead_attributes.first
    first_interview_attributes = builder.interview_attributes.first

    assert_same demo.user, first_lead_attributes.fetch(:user)
    assert_equal 10.days.ago + 9.hours, first_lead_attributes.fetch(:applied_at)
    assert_equal "interview", first_lead_attributes.fetch(:status)

    assert_same demo.leads.first, first_interview_attributes.fetch(:job_lead)
    assert_equal 2.days.from_now + 14.hours, first_interview_attributes.fetch(:scheduled_at)
    assert_not first_interview_attributes.key?(:lead_index)
  end

  private

  class RecordingRecordBuilder
    attr_reader :lead_attributes, :interview_attributes

    def initialize
      @lead_attributes = []
      @interview_attributes = []
    end

    def lead(attributes)
      lead_attributes << attributes
      JobLead.new(
        id: attributes.fetch(:id),
        user: attributes.fetch(:user),
        title: attributes.fetch(:title),
        company: attributes.fetch(:company),
        application_url: attributes.fetch(:application_url)
      )
    end

    def interview(attributes)
      interview_attributes << attributes
      Interview.new(
        id: attributes.fetch(:id),
        job_lead: attributes.fetch(:job_lead),
        interviewer: attributes.fetch(:interviewer),
        scheduled_at: attributes.fetch(:scheduled_at),
        location: attributes.fetch(:location)
      )
    end
  end
end
