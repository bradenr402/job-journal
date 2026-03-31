class PagesController < ApplicationController
  allow_unauthenticated_access only: :landing
  layout 'landing', only: :landing

  before_action :cleanup_leads, only: :home

  def landing
    @demo_leads = [
      { title: "Senior Software Engineer", company: "Stripe", status: "interview", status_label: "Interview", status_date: "Mar 24", tags: [ "remote", "dream job" ], notes_count: 5, updated: "2 days ago" },
      { title: "Staff Frontend Developer", company: "Notion", status: "applied", status_label: "Applied", status_date: "Mar 21", tags: [ "hybrid", "series-b" ], notes_count: 2, updated: "4 days ago" },
      { title: "Principal Engineer", company: "Vercel", status: "offer", status_label: "Offer", status_date: "Mar 26", tags: [ "remote", "referral" ], notes_count: 8, updated: "1 day ago" },
      { title: "Engineering Manager", company: "Shopify", status: "lead", status_label: "Lead", status_date: "Mar 18", tags: [ "remote" ], notes_count: 0, updated: "1 week ago" }
    ]

    @demo_interviews = [
      { interviewer: "Sarah Chen", title: "Senior Software Engineer", company: "Stripe", status_label: "Scheduled", date: "Wed, Mar 26 · 2:00 PM", location: "Google Meet", notes_count: 3, updated: "1 day ago" },
      { interviewer: "James Park", title: "Staff Frontend Developer", company: "Notion", status_label: "Completed", date: "Mon, Mar 17 · 10:30 AM", location: "On-site · SF Office", notes_count: 4, updated: "1 week ago" }
    ]

    @demo_notes = [
      { icon: "briefcase-filled", title: "Stripe — Culture & Comp Research", content: "Stripe's engineering culture emphasizes writing and clear thinking. Comp bands for L5 are $220–280k base + equity. Interview process is typically 5 rounds: recruiter screen, technical phone screen, 2 system design, 1 hiring manager." },
      { icon: "interview-filled", title: "Notion — Interview Prep Notes", content: "Review their Blocks data model and real-time collaboration architecture. Prepare to discuss how I'd approach offline-first sync. Brush up on CRDTs and operational transforms." },
      { icon: "briefcase-filled", title: "Vercel — Offer Negotiation", content: "Initial offer: $245k base, $180k RSUs over 4 years, $25k signing bonus. Want to negotiate equity — comparable roles at this level are closer to $250k in RSUs. Set deadline to respond by April 2." },
      { icon: "interview-filled", title: "Shopify — Recruiter Call Debrief", content: "Recruiter mentioned the team is fully remote, working on checkout infrastructure. They're looking for someone to lead a team of 4–6 engineers. Next step is a technical screen with the hiring manager." }
    ]

    @demo_stats = [
      { label: "Job Leads This Week", icon: "briefcase", count: 12, change: "+4 from last week" },
      { label: "Applications This Week", icon: "application", count: 7, change: "+3 from last week" },
      { label: "Interviews This Week", icon: "interview", count: 3, change: "+1 from last week" }
    ]
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
end
