class PagesController < ApplicationController
  allow_unauthenticated_access only: :landing
  layout 'landing', only: :landing

  before_action :cleanup_leads, only: :home

  def landing
    build_demo_data
  end

  def home
    stats = DashboardStats.new(Current.user).stats
    stats.each_pair { |key, value| instance_variable_set("@#{key}", value) }
  end

  def security
    @sessions = Current.user.sessions.order(updated_at: :desc)
  end

  private

  def cleanup_leads
    JobLead.cleanup_for_user(Current.user)
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def build_demo_data
    demo_user = User.new(id: 0, name: 'Demo User')

    # ── Job Leads ──────────────────────────────────────────────
    stripe_lead = demo_lead(
      id: 1001, user: demo_user,
      title: 'Senior Software Engineer', company: 'Stripe',
      application_url: 'https://stripe.com/jobs/1234',
      applied_at: 10.days.ago + 9.hours,
      created_at: 14.days.ago + 2.hours + 17.minutes, updated_at: 2.days.ago + 11.hours + 42.minutes,
      status: 'interview', status_at: 5.days.ago + 14.hours + 5.minutes,
      tags: [ 'remote', 'dream job' ], notes_count: 5
    )

    notion_lead = demo_lead(
      id: 1002, user: demo_user,
      title: 'Staff Frontend Developer', company: 'Notion',
      application_url: 'https://notion.so/careers/5678',
      applied_at: 8.days.ago + 15.hours + 30.minutes,
      created_at: 12.days.ago + 10.hours + 51.minutes, updated_at: 4.days.ago + 8.hours + 3.minutes,
      status: 'applied', status_at: 8.days.ago + 15.hours + 30.minutes,
      tags: [ 'hybrid', 'series-b' ], notes_count: 2
    )

    vercel_lead = demo_lead(
      id: 1003, user: demo_user,
      title: 'Principal Engineer', company: 'Vercel',
      application_url: 'https://vercel.com/careers/9012',
      applied_at: 20.days.ago + 11.hours + 22.minutes, offer_at: 3.days.ago + 16.hours + 48.minutes,
      created_at: 25.days.ago + 17.hours + 9.minutes, updated_at: 3.days.ago + 16.hours + 50.minutes,
      status: 'offer', status_at: 3.days.ago + 16.hours + 48.minutes,
      tags: [ 'remote', 'referral' ], notes_count: 8
    )

    shopify_lead = demo_lead(
      id: 1004, user: demo_user,
      title: 'Engineering Manager', company: 'Shopify',
      application_url: 'https://shopify.com/careers/3456',
      created_at: 11.days.ago + 13.hours + 34.minutes, updated_at: 7.days.ago + 9.hours + 17.minutes,
      status: 'lead', status_at: 11.days.ago + 13.hours + 34.minutes,
      tags: [ 'remote' ], notes_count: 0
    )

    @demo_leads = [ stripe_lead, notion_lead, vercel_lead, shopify_lead ]

    # ── Interviews ─────────────────────────────────────────────
    stripe_interview = demo_interview(
      id: 2001, job_lead: stripe_lead,
      interviewer: 'Sarah Chen',
      scheduled_at: 2.days.from_now + 14.hours,
      location: 'Google Meet',
      created_at: 3.days.ago + 10.hours + 28.minutes, updated_at: 1.day.ago + 16.hours + 5.minutes,
      notes_count: 3
    )

    notion_interview = demo_interview(
      id: 2002, job_lead: notion_lead,
      interviewer: 'James Park',
      scheduled_at: 12.days.ago + 10.hours,
      location: 'On-site · SF Office',
      rating: 4,
      created_at: 14.days.ago + 11.hours + 15.minutes, updated_at: 11.days.ago + 22.hours + 37.minutes,
      notes_count: 4
    )

    @demo_interviews = [ stripe_interview, notion_interview ]

    # ── Notes ──────────────────────────────────────────────────
    @demo_notes = [
      Note.new(
        id: 3001, user: demo_user, notable: stripe_lead,
        content: "Stripe's engineering culture emphasizes writing and clear thinking. Comp bands for L5 are $220–280k base + equity. Interview process is typically 5 rounds: recruiter screen, technical phone screen, 2 system design, 1 hiring manager.",
        created_at: 5.days.ago + 19.hours + 12.minutes, updated_at: 5.days.ago + 19.hours + 12.minutes
      ),
      Note.new(
        id: 3002, user: demo_user, notable: notion_interview,
        content: "Review their Blocks data model and real-time collaboration architecture. Prepare to discuss how I'd approach offline-first sync. Brush up on CRDTs and operational transforms.",
        created_at: 13.days.ago + 8.hours + 44.minutes, updated_at: 11.days.ago + 21.hours + 3.minutes
      ),
      Note.new(
        id: 3003, user: demo_user, notable: vercel_lead,
        content: 'Initial offer: $245k base, $180k RSUs over 4 years, $25k signing bonus. Want to negotiate equity — comparable roles at this level are closer to $250k in RSUs. Set deadline to respond by April 2.',
        created_at: 3.days.ago + 17.hours + 22.minutes, updated_at: 3.days.ago + 17.hours + 22.minutes
      ),
      Note.new(
        id: 3004, user: demo_user, notable: shopify_lead,
        content: "Recruiter mentioned the team is fully remote, working on checkout infrastructure. They're looking for someone to lead a team of 4–6 engineers. Next step is a technical screen with the hiring manager.",
        created_at: 1.day.ago + 11.hours + 58.minutes, updated_at: 1.day.ago + 11.hours + 58.minutes
      )
    ]

    # ── Stats (rendered inline, no partial) ────────────────────
    @demo_stats = [
      { label: 'Job Leads This Week', icon: 'briefcase', count: 12, change: '+4 from last week' },
      { label: 'Applications This Week', icon: 'application', count: 7, change: '+3 from last week' },
      { label: 'Interviews This Week', icon: 'interview', count: 3, change: '+1 from last week' }
    ]
  end

  # Builds a JobLead with preloaded associations and an overridden status
  # to avoid DB queries on the landing page.
  def demo_lead(status:, status_at:, tags: [], notes_count: 0, **attrs)
    lead = JobLead.new(**attrs)
    lead.define_singleton_method(:status) { status }
    lead.define_singleton_method(:latest_status_at) { status_at }

    preload_association(lead, :tags, tags.map.with_index { |name, i| Tag.new(id: 4000 + lead.id * 10 + i, name: name) })
    preload_association(lead, :notes, notes_count.times.map { |i| Note.new(id: 5000 + lead.id * 10 + i) })
    lead
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # Builds an Interview with preloaded notes.
  def demo_interview(notes_count: 0, **attrs)
    interview = Interview.new(**attrs)
    preload_association(interview, :notes, notes_count.times.map { |i| Note.new(id: 6000 + interview.id * 10 + i) })
    interview
  end

  # Sets an association's in-memory target so the partial can read it
  # without hitting the database.
  def preload_association(record, name, records)
    assoc = record.association(name)
    assoc.target = records
    assoc.loaded!
  end
end
