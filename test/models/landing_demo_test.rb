require "test_helper"

class LandingDemoTest < ActiveSupport::TestCase
  test "exposes all landing page demo data from one object" do
    demo = LandingDemo.new

    assert_equal "Demo User", demo.user.name
    assert_equal %w[Stripe Notion Vercel Shopify], demo.leads.map(&:company)
    assert_equal [ "interview", "applied", "offer", "lead" ], demo.leads.map(&:status)
    assert_equal 2, demo.interviews.size
    assert_equal 6, demo.notes.size

    assert_equal({ count: 12, change: "+4 from last week" }, demo.job_lead_stats)
    assert_equal({ count: 7, change: "+3 from last week", goal: 10 }, demo.application_stats)
    assert_equal({ count: 3, change: "+1 from last week", average_rating: 4.0 }, demo.interview_stats)
    assert_equal [ "remote", "hybrid", "referral", "dream job", "series-b", "priority" ], demo.top_tags
  end

  test "preloads demo associations for partials" do
    demo = LandingDemo.new

    lead = demo.leads.first
    assert_predicate lead.association(:tags), :loaded?
    assert_predicate lead.association(:notes), :loaded?
    assert_equal [ "remote", "dream job" ], lead.tags.map(&:name)
    assert_equal 5, lead.notes.size

    interview = demo.interviews.first
    assert_predicate interview.association(:notes), :loaded?
    assert_equal 3, interview.notes.size
  end

  test "provides source insight data in the shape expected by the sources partial" do
    sources = LandingDemo.new.sources

    assert_equal [ "Referral", "Company Website", "LinkedIn", "Indeed" ], sources.keys
    assert_equal(
      {
        lead_count: 4,
        interview_count: 2,
        offer_count: 0,
        accepted_count: 0,
        conversion_rate: 2.0 / 4
      },
      sources.fetch("Referral")
    )
  end
end
