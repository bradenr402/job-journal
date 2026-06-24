# Demo user for screenshots and development
# Usage: bin/rails db:seed
#
# Login: demo@jobjournal.app / password

puts "Seeding demo data..."

# ── User ──
user = User.find_or_create_by!(email_address: "demo@jobjournal.app") do |u|
  u.name = "Demo User"
  u.password = "password"
  u.password_confirmation = "password"
  u.settings = User::DEFAULT_SETTINGS.merge("weekly_application_goal" => 10)
end
user.update!(
  name: "Demo User",
  settings: User::DEFAULT_SETTINGS.merge("weekly_application_goal" => 10)
)

puts "  Created user: #{user.email_address}"

# Clean up existing demo data for idempotency
user.notes.destroy_all
Interview.where(job_lead: user.job_leads).destroy_all
user.job_leads.destroy_all
user.tags.destroy_all

# ── Tags ──
tag_names = %w[remote hybrid on-site startup enterprise referral priority]
tags = tag_names.each_with_object({}) do |name, hash|
  hash[name] = user.tags.create!(name: name)
end

puts "  Created #{tags.size} tags"

# ── Helper ──
# Clamp any timestamp to be safely in the past
def past(time)
  [time, 1.minute.ago].min
end

now = Time.current
mon0 = now.beginning_of_week            # Monday this week
mon1 = mon0 - 1.week                    # Monday last week
mon2 = mon0 - 2.weeks                   # Monday two weeks ago

# ── Job Leads ──

# 1. Accepted offer — the success story
stripe = user.job_leads.create!(
  company: "Stripe",
  title: "Senior Software Engineer",
  application_url: "https://stripe.com/jobs/listing/senior-software-engineer/6234",
  source: "LinkedIn",
  salary: "$180k - $220k",
  location: "Remote (US)",
  offer_amount: 205_000,
  created_at: mon2,
  applied_at: past(mon2 + 1.day),
  offer_at: past(mon1 + 4.days),
  accepted_at: past(mon0)
)
stripe.tags << [tags["remote"], tags["priority"]]

# 2. Active offer pending decision
notion = user.job_leads.create!(
  company: "Notion",
  title: "Full Stack Developer",
  application_url: "https://notion.so/careers/full-stack-developer/4821",
  source: "Referral",
  salary: "$150k - $175k",
  location: "San Francisco, CA (Hybrid)",
  offer_amount: 155_000,
  created_at: mon2 + 2.days,
  applied_at: past(mon2 + 3.days),
  offer_at: past(mon1 + 3.days)
)
notion.tags << [tags["hybrid"], tags["referral"]]

# 3. Interview stage — upcoming interview
shopify = user.job_leads.create!(
  company: "Shopify",
  title: "Backend Engineer",
  application_url: "https://shopify.com/careers/backend-engineer/9102",
  source: "LinkedIn",
  salary: "$160k - $190k",
  location: "Remote (US/Canada)",
  created_at: mon1,
  applied_at: past(mon1 + 1.day)
)
shopify.tags << [tags["remote"], tags["enterprise"]]

# 4. Interview stage — past interview, rated well
airbnb = user.job_leads.create!(
  company: "Airbnb",
  title: "Software Engineer",
  application_url: "https://airbnb.com/careers/software-engineer/3847",
  source: "Company Website",
  salary: "$170k - $200k",
  location: "San Francisco, CA (Hybrid)",
  created_at: mon2 + 1.day,
  applied_at: past(mon2 + 2.days)
)
airbnb.tags << [tags["hybrid"], tags["priority"]]

# 5. Applied this week
github = user.job_leads.create!(
  company: "GitHub",
  title: "Staff Engineer",
  application_url: "https://github.com/about/careers/staff-engineer/2938",
  source: "Referral",
  salary: "$200k - $250k",
  location: "Remote (US)",
  created_at: mon0,
  applied_at: past(mon0 + 6.hours)
)
github.tags << [tags["remote"], tags["referral"], tags["priority"]]

# 6. Applied last week
figma = user.job_leads.create!(
  company: "Figma",
  title: "Product Engineer",
  application_url: "https://figma.com/careers/product-engineer/7293",
  source: "LinkedIn",
  salary: "$155k - $185k",
  location: "New York, NY (Hybrid)",
  created_at: mon1 + 1.day,
  applied_at: past(mon1 + 2.days)
)
figma.tags << [tags["hybrid"]]

# 7. Lead — saved this week, not yet applied
vercel = user.job_leads.create!(
  company: "Vercel",
  title: "Platform Engineer",
  application_url: "https://vercel.com/careers/platform-engineer/5102",
  source: "Hacker News",
  location: "Remote",
  created_at: past(mon0 + 8.hours)
)
vercel.tags << [tags["remote"], tags["startup"]]

# 8. Lead — saved recently
linear = user.job_leads.create!(
  company: "Linear",
  title: "Senior Developer",
  application_url: "https://linear.app/careers/senior-developer/8321",
  source: "Referral",
  location: "Remote",
  created_at: past(mon0 + 4.hours)
)
linear.tags << [tags["remote"], tags["startup"], tags["referral"]]

# 9. Rejected last week
slack = user.job_leads.create!(
  company: "Slack",
  title: "Frontend Engineer",
  application_url: "https://slack.com/careers/frontend-engineer/4523",
  source: "Indeed",
  salary: "$140k - $170k",
  location: "Denver, CO (Hybrid)",
  created_at: mon2 + 3.days,
  applied_at: past(mon2 + 4.days),
  rejected_at: past(mon1 + 3.days)
)
slack.tags << [tags["hybrid"], tags["enterprise"]]

# 10. Rejected two weeks ago
dropbox = user.job_leads.create!(
  company: "Dropbox",
  title: "Software Engineer II",
  application_url: "https://dropbox.com/jobs/software-engineer-ii/6721",
  source: "LinkedIn",
  salary: "$145k - $175k",
  location: "Remote (US)",
  created_at: mon2,
  applied_at: past(mon2 + 1.day),
  rejected_at: past(mon2 + 5.days)
)
dropbox.tags << [tags["remote"]]

# 11. Applied this week
netflix = user.job_leads.create!(
  company: "Netflix",
  title: "Senior Engineer",
  application_url: "https://netflix.com/jobs/senior-engineer/8934",
  source: "Company Website",
  salary: "$200k - $350k",
  location: "Remote (US)",
  created_at: mon0,
  applied_at: past(mon0 + 10.hours)
)
netflix.tags << [tags["remote"], tags["priority"]]

# 12. Lead — saved a few days ago
square = user.job_leads.create!(
  company: "Square",
  title: "Backend Developer",
  application_url: "https://squareup.com/careers/backend-developer/3401",
  source: "Job Board",
  location: "Oakland, CA (Hybrid)",
  created_at: past(mon0 + 6.hours)
)
square.tags << [tags["hybrid"]]

# 13. Applied last week
coinbase = user.job_leads.create!(
  company: "Coinbase",
  title: "Platform Engineer",
  application_url: "https://coinbase.com/careers/platform-engineer/2918",
  source: "AngelList",
  salary: "$165k - $195k",
  location: "Remote",
  created_at: mon1 + 2.days,
  applied_at: past(mon1 + 3.days)
)
coinbase.tags << [tags["remote"], tags["startup"]]

# 14. Interview stage — past interview
datadog = user.job_leads.create!(
  company: "Datadog",
  title: "Site Reliability Engineer",
  application_url: "https://datadog.com/careers/sre/7439",
  source: "Recruiter",
  salary: "$170k - $200k",
  location: "New York, NY (Hybrid)",
  created_at: mon2 + 2.days,
  applied_at: past(mon2 + 3.days)
)
datadog.tags << [tags["hybrid"], tags["enterprise"]]

puts "  Created #{user.job_leads.count} job leads"

# ── Interviews ──

# Shopify — upcoming interview (2 days from now)
shopify.interviews.create!(
  interviewer: "Sarah Chen",
  scheduled_at: now + 2.days,
  location: "Remote",
  call_url: "https://meet.google.com/abc-defg-hij"
)

# Airbnb — past interview, rated well
airbnb_interview = airbnb.interviews.create!(
  interviewer: "James Park",
  scheduled_at: past(mon0 + 10.hours),
  location: "San Francisco, CA",
  rating: 4
)

# Airbnb — second interview upcoming
airbnb.interviews.create!(
  interviewer: "Lisa Wang",
  scheduled_at: now + 4.days,
  location: "Remote",
  call_url: "https://zoom.us/j/12345678"
)

# Datadog — past interview
datadog_interview = datadog.interviews.create!(
  interviewer: "Mike Thompson",
  scheduled_at: past(mon1 + 14.hours),
  location: "Remote",
  call_url: "https://meet.google.com/xyz-uvwx-rst",
  rating: 3
)

# Stripe — past interviews (part of the success story)
stripe_interview_1 = stripe.interviews.create!(
  interviewer: "Rachel Kim",
  scheduled_at: past(mon1 + 10.hours),
  location: "Remote",
  call_url: "https://zoom.us/j/98765432",
  rating: 5
)

stripe.interviews.create!(
  interviewer: "David Liu",
  scheduled_at: past(mon1 + 3.days + 14.hours),
  location: "Remote",
  call_url: "https://zoom.us/j/55667788",
  rating: 4
)

# Notion — past interview
notion.interviews.create!(
  interviewer: "Emily Garcia",
  scheduled_at: past(mon1 + 2.days + 11.hours),
  location: "San Francisco, CA",
  rating: 4
)

puts "  Created #{Interview.where(job_lead: user.job_leads).count} interviews"

# ── Notes ──

user.notes.create!(notable: stripe, content: "Really excited about this role. The team works on payment infrastructure and the tech stack is exactly what I've been looking for. Culture seems excellent based on Glassdoor reviews.")
user.notes.create!(notable: stripe, content: "Offer details: $205k base + equity package. Great benefits including unlimited PTO and home office stipend. Need to respond by Friday.")

user.notes.create!(notable: notion, content: "Referred by Alex from my previous company. The product team is relatively small which means more ownership. They use Rails which is a plus.")

user.notes.create!(notable: github, content: "This is a staff-level role so the bar will be high. Need to brush up on system design and prepare examples of leading cross-team projects.")

user.notes.create!(notable: shopify, content: "Interesting backend challenges at scale. They process millions of transactions daily. Prepare questions about their monolith-to-services migration.")

user.notes.create!(notable: airbnb, content: "Company research: Airbnb has been profitable for several quarters now. Engineering culture seems strong. They value craft and attention to detail.")

user.notes.create!(notable: netflix, content: "The famous Netflix culture deck is worth re-reading before applying. They pay top of market but expect high performance. No formal levels which is interesting.")

user.notes.create!(notable: vercel, content: "Would love to work on Next.js infrastructure. Smaller company but growing fast. Check if they offer equity refresh grants.")

user.notes.create!(notable: stripe_interview_1, content: "**Prep:**\n- Review distributed systems patterns\n- Practice coding on whiteboard\n- Prepare 3 examples of technical leadership\n\n**Debrief:** Went really well! Rachel was friendly and the technical questions were challenging but fair. Focused on system design for payment processing.")

user.notes.create!(notable: airbnb_interview, content: "**Questions they asked:**\n1. Design a booking system with concurrent reservations\n2. Walk through a time you resolved a production incident\n3. How do you approach code reviews?\n\nFelt good about my answers. James mentioned next steps would be an onsite.")

user.notes.create!(notable: datadog_interview, content: "Mixed feelings. The technical portion went well but I struggled a bit with the monitoring infrastructure question. Should study more about observability patterns before a potential next round.")

puts "  Created #{user.notes.count} notes"

puts "Done! Sign in with: demo@jobjournal.app / password"
