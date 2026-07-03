class LandingDemo
  module Data
    LEADS = [
      {
        id: 1001, title: "Senior Software Engineer", company: "Stripe",
        application_url: "https://stripe.com/jobs/1234",
        applied_at: -> { 10.days.ago + 9.hours },
        created_at: -> { 14.days.ago + 2.hours + 17.minutes },
        updated_at: -> { 2.days.ago + 11.hours + 42.minutes },
        status: "interview", status_at: -> { 5.days.ago + 14.hours + 5.minutes },
        tags: [ "remote", "dream job" ], notes_count: 5
      },
      {
        id: 1002, title: "Staff Frontend Developer", company: "Notion",
        application_url: "https://notion.so/careers/5678",
        applied_at: -> { 8.days.ago + 15.hours + 30.minutes },
        created_at: -> { 12.days.ago + 10.hours + 51.minutes },
        updated_at: -> { 4.days.ago + 8.hours + 3.minutes },
        status: "applied", status_at: -> { 8.days.ago + 15.hours + 30.minutes },
        tags: [ "hybrid", "referral" ], notes_count: 2
      },
      {
        id: 1003, title: "Principal Engineer", company: "Vercel",
        application_url: "https://vercel.com/careers/9012",
        applied_at: -> { 20.days.ago + 11.hours + 22.minutes },
        offer_at: -> { 3.days.ago + 16.hours + 48.minutes },
        created_at: -> { 25.days.ago + 17.hours + 9.minutes },
        updated_at: -> { 3.days.ago + 16.hours + 50.minutes },
        status: "offer", status_at: -> { 3.days.ago + 16.hours + 48.minutes },
        tags: [ "remote", "referral" ], notes_count: 8
      },
      {
        id: 1004, title: "Engineering Manager", company: "Shopify",
        application_url: "https://shopify.com/careers/3456",
        created_at: -> { 11.days.ago + 13.hours + 34.minutes },
        updated_at: -> { 7.days.ago + 9.hours + 17.minutes },
        status: "lead", status_at: -> { 11.days.ago + 13.hours + 34.minutes },
        tags: [ "remote" ], notes_count: 0
      }
    ].freeze

    INTERVIEWS = [
      {
        id: 2001, lead_index: 0, interviewer: "Sarah Chen",
        scheduled_at: -> { 2.days.from_now + 14.hours },
        location: "Google Meet",
        created_at: -> { 3.days.ago + 10.hours + 28.minutes },
        updated_at: -> { 1.day.ago + 16.hours + 5.minutes },
        notes_count: 3
      },
      {
        id: 2002, lead_index: 1, interviewer: "James Park",
        scheduled_at: -> { 12.days.ago + 10.hours },
        location: "On-site at SF Office", rating: 4,
        created_at: -> { 14.days.ago + 11.hours + 15.minutes },
        updated_at: -> { 11.days.ago + 22.hours + 37.minutes },
        notes_count: 4
      }
    ].freeze

    NOTES = [
      {
        id: 3001, notable: [ :leads, 0 ],
        content: "Stripe's engineering culture emphasizes writing and clear thinking. Comp bands for L5 are $220–280k base + equity. Interview process is typically 5 rounds: recruiter screen, technical phone screen, 2 system design, 1 hiring manager.",
        created_at: -> { 5.days.ago + 19.hours + 12.minutes },
        updated_at: -> { 5.days.ago + 19.hours + 12.minutes }
      },
      {
        id: 3006, notable: [ :leads, 1 ],
        content: "Followed up via email. He mentioned that the team is still reviewing applications and will get back to me within the next week.",
        created_at: -> { 10.days.ago + 14.hours + 33.minutes },
        updated_at: -> { 10.days.ago + 14.hours + 33.minutes }
      },
      {
        id: 3003, notable: [ :leads, 2 ],
        content: -> { "Initial offer: $245k base, $180k RSUs over 4 years, $25k signing bonus. Want to negotiate equity—comparable roles at this level are closer to $250k in RSUs. Set deadline to respond by #{10.days.from_now.strftime "%B %e"}." },
        created_at: -> { 3.days.ago + 17.hours + 22.minutes },
        updated_at: -> { 3.days.ago + 17.hours + 22.minutes }
      },
      {
        id: 3004, notable: [ :leads, 3 ],
        content: "Recruiter mentioned the team is fully remote, working on checkout infrastructure. They're looking for someone to lead a team of 4–6 engineers. Next step is a technical screen with the hiring manager.",
        created_at: -> { 1.day.ago + 11.hours + 58.minutes },
        updated_at: -> { 1.day.ago + 11.hours + 58.minutes }
      },
      {
        id: 3005, notable: [ :interviews, 0 ],
        content: "Interview went well. Sarah asked about my experience with distributed systems and how I would design a scalable payment processing system. She seemed impressed with my approach to handling edge cases.",
        created_at: -> { 1.day.ago + 15.hours + 7.minutes },
        updated_at: -> { 1.day.ago + 15.hours + 7.minutes }
      },
      {
        id: 3002, notable: [ :interviews, 1 ],
        content: "Review their Blocks data model and real-time collaboration architecture. Prepare to discuss how I'd approach offline-first sync. Brush up on CRDTs and operational transforms.",
        created_at: -> { 13.days.ago + 8.hours + 44.minutes },
        updated_at: -> { 11.days.ago + 21.hours + 3.minutes }
      }
    ].freeze

    SUGGESTIONS = [
      { title: "Staff Frontend Developer", company: "Notion", status: "applied", status_at: -> { 8.days.ago } },
      { title: "Senior Software Engineer", company: "Stripe", status: "interview", status_at: -> { 5.days.ago } }
    ].freeze

    STALE_LEADS = [
      {
        id: 1005, title: "Engineering Manager", company: "Shopify",
        application_url: "https://shopify.com/careers/8910",
        created_at: -> { 19.days.ago + 4.hours + 1.minute },
        updated_at: -> { 19.days.ago + 4.hours + 1.minute },
        status: "lead", status_at: -> { 19.days.ago + 4.hours + 1.minute }
      },
      {
        id: 1006, title: "Senior Security Engineer", company: "OpenAI",
        application_url: "https://openai.com/careers/1112",
        created_at: -> { 27.days.ago + 3.hours - 12.minutes },
        updated_at: -> { 27.days.ago + 3.hours - 12.minutes },
        status: "lead", status_at: -> { 27.days.ago + 3.hours - 12.minutes }
      }
    ].freeze

    JOB_LEAD_STATS = { count: 12, change: "+4 from last week" }.freeze
    APPLICATION_STATS = { count: 7, change: "+3 from last week", goal: 10 }.freeze
    INTERVIEW_STATS = { count: 3, change: "+1 from last week", average_rating: 4.0 }.freeze
    TOP_TAGS = [ "remote", "hybrid", "referral", "dream job", "series-b", "priority" ].freeze

    SOURCES = {
      "Referral" => { lead_count: 4, interview_count: 2, offer_count: 0, accepted_count: 0, conversion_rate: 2.0 / 4 },
      "Company Website" => { lead_count: 9, interview_count: 2, offer_count: 1, accepted_count: 0, conversion_rate: 3.0 / 9 },
      "LinkedIn" => { lead_count: 12, interview_count: 4, offer_count: 0, accepted_count: 0, conversion_rate: 4.0 / 12 },
      "Indeed" => { lead_count: 8, interview_count: 1, offer_count: 0, accepted_count: 0, conversion_rate: 1.0 / 8 }
    }.freeze
  end
end
