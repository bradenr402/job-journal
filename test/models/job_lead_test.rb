require "test_helper"

class JobLeadTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @lead = job_leads(:one)
  end

  teardown do
    JobLead.destroy_all
  end

  test "should be valid with valid attributes" do
    assert @lead.valid?
  end

  test "should require title" do
    @lead.title = ""
    assert_not @lead.valid?
    assert_includes @lead.errors[:title], "can't be blank"
  end

  test "should require company" do
    @lead.company = ""
    assert_not @lead.valid?
    assert_includes @lead.errors[:company], "can't be blank"
  end

  test "should require application_url" do
    @lead.application_url = ""
    assert_not @lead.valid?
    assert_includes @lead.errors[:application_url], "can't be blank"
  end

  test "should require a valid application_url" do
    @lead.application_url = "not_a_valid_url"
    assert_not @lead.valid?
    assert_includes @lead.errors[:application_url], "is invalid"
  end

  test "should require a unique application_url" do
    @lead.application_url = "https://example.com/apply"
    @lead.save!

    duplicate = @lead.dup
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:application_url], "has already been taken"
  end

  test "should enforce numericality of offer_amount" do
    lead = build_job_lead(offer_amount: -100)

    assert_not lead.valid?
    assert_includes lead.errors[:offer_amount], "must be greater than or equal to 0"
  end

  test "should allow zero offer_amount without an offer timestamp" do
    lead = build_job_lead(offer_amount: 0)

    assert lead.valid?
  end

  test "should reject zero offer_amount when offer_at is present" do
    lead = build_job_lead(offer_amount: 0, offer_at: Time.current)

    assert_not lead.valid?
    assert_includes lead.errors[:base], "cannot advance to Offer without specifying an offer amount"
  end

  test "should validate temporal logic on status timestamps" do
    %i[applied_at offer_at rejected_at accepted_at].each do |attribute|
      lead = build_job_lead(attribute => 1.day.from_now)
      lead.offer_amount = 100_000 if attribute == :offer_at # satisfy the offer validation

      assert_not lead.valid?, "#{attribute} should not allow future timestamps"
      assert lead.errors[attribute].any? { |msg| msg.include? "must be less than or equal to" }
    end
  end

  test "should allow current time for status timestamps" do
    freeze_time

    %i[applied_at offer_at rejected_at accepted_at].each do |attribute|
      lead = build_job_lead(attribute => Time.current)
      lead.offer_amount = 100_000 if attribute == :offer_at

      assert lead.valid?, "#{attribute} should allow Time.current"
    end
  end

  test "should normalize squishable text attributes" do
    lead = create_job_lead(
      title: "  Junior   Programmer  ",
      company: "  Example    Co  ",
      salary: "  $100K   -   $120K  ",
      contact: "  Jane   Doe  ",
      location: "  Remote    US  ",
      source: "  Company    Site  "
    )

    assert_equal "Junior Programmer", lead.title
    assert_equal "Example Co", lead.company
    assert_equal "$100K - $120K", lead.salary
    assert_equal "Jane Doe", lead.contact
    assert_equal "Remote US", lead.location
    assert_equal "Company Site", lead.source
  end

  test "status scopes return leads matching their inferred statuses" do
    freeze_time

    JobLead.destroy_all

    lead = create_job_lead(created_at: 6.days.ago)
    applied = create_job_lead(applied_at: 5.days.ago)
    interview = create_job_lead
    create_interview(job_lead: interview, scheduled_at: 4.days.ago)
    create_interview(job_lead: interview, scheduled_at: 3.days.ago)

    offer = create_job_lead(offer_amount: 120_000, offer_at: 3.days.ago)
    rejected = create_job_lead(rejected_at: 2.days.ago)
    accepted = create_job_lead(accepted_at: 1.day.ago)

    assert_includes JobLead.lead, lead
    assert_includes JobLead.applied, applied
    assert_includes JobLead.interview, interview
    assert_includes JobLead.offer, offer
    assert_includes JobLead.rejected, rejected
    assert_includes JobLead.accepted, accepted
  end

  test "with_status returns a matching status scope" do
    JobLead.destroy_all
    applied = create_job_lead(applied_at: Time.current)
    create_job_lead

    assert_includes JobLead.with_status(:applied), applied
  end

  test "with_status rejects unknown statuses" do
    assert_raises(ArgumentError) { JobLead.with_status(:missing) }
  end

  test "with_any_status returns leads matching any requested status" do
    JobLead.destroy_all
    applied = create_job_lead(applied_at: Time.current)
    rejected = create_job_lead(rejected_at: Time.current)
    create_job_lead

    any_status = JobLead.with_any_status(%w[applied rejected])

    assert_includes any_status, applied
    assert_includes any_status, rejected
  end

  test "with_any_status raises on unknown statuses" do
    error = assert_raises(ArgumentError) { JobLead.with_any_status(%i[ lead bogus ]) }

    assert_equal "Invalid status: bogus", error.message
  end

  test "with_any_status raises when evaluated with no statuses" do
    assert_raises(ActiveRecord::StatementInvalid) { JobLead.with_any_status([]).load }
  end

  test "active and archived scopes split by archived_at" do
    JobLead.destroy_all
    active = create_job_lead
    archived = create_job_lead(archived_at: Time.current)

    assert_includes JobLead.active, active
    assert_includes JobLead.archived, archived
  end

  test "stale_for_user returns active lead-status records at or before the user cutoff" do
    freeze_time

    @user.update_settings(archiving: { stale: { mark_after_days: 7 } })
    JobLead.destroy_all

    old = create_job_lead(created_at: 8.days.ago)
    boundary = create_job_lead(created_at: 7.days.ago)
    create_job_lead(created_at: 6.days.ago)
    create_job_lead(created_at: 8.days.ago, archived_at: Time.current)
    create_job_lead(applied_at: 8.days.ago, created_at: 8.days.ago)
    interview = create_job_lead(created_at: 8.days.ago)
    create_interview(job_lead: interview, scheduled_at: 1.day.from_now)

    stale = JobLead.stale_for_user(@user)

    assert_includes stale, old
    assert_includes stale, boundary
  end

  test "application_follow_up_for_user returns active applications inside the reminder window" do
    freeze_time

    @user.update_settings(follow_ups: { application_days: 7 })
    @user.update_settings(follow_ups: { suggestion_days: 3 })
    JobLead.destroy_all

    start_boundary = create_job_lead(applied_at: 10.days.ago)
    end_boundary = create_job_lead(applied_at: 7.days.ago)
    create_job_lead(applied_at: 11.days.ago)
    create_job_lead(applied_at: 6.days.ago)
    create_job_lead(applied_at: 8.days.ago, archived_at: Time.current)
    create_job_lead(created_at: 8.days.ago)

    follow_ups = JobLead.application_follow_up_for_user(@user)

    assert_includes follow_ups, start_boundary
    assert_includes follow_ups, end_boundary
  end

  test "interview_follow_up_for_user returns active interviews inside the reminder window" do
    freeze_time

    @user.update_settings(follow_ups: { interview_days: 2 })
    @user.update_settings(follow_ups: { suggestion_days: 3 })
    JobLead.destroy_all

    start_boundary = create_job_lead
    create_interview(job_lead: start_boundary, scheduled_at: 5.days.ago)
    end_boundary = create_job_lead
    create_interview(job_lead: end_boundary, scheduled_at: 2.days.ago)

    too_old = create_job_lead
    create_interview(job_lead: too_old, scheduled_at: 6.days.ago)
    too_recent = create_job_lead
    create_interview(job_lead: too_recent, scheduled_at: 1.day.ago)
    archived = create_job_lead(archived_at: Time.current)
    create_interview(job_lead: archived, scheduled_at: 3.days.ago)
    offer = create_job_lead(offer_amount: 100_000, offer_at: 1.day.ago)
    create_interview(job_lead: offer, scheduled_at: 3.days.ago)

    follow_ups = JobLead.interview_follow_up_for_user(@user)

    assert_includes follow_ups, start_boundary
    assert_includes follow_ups, end_boundary
  end

  test "tag scopes filter by one, all, or any tag names" do
    JobLead.destroy_all
    ruby = tag_named("ruby")
    rails = tag_named("rails")
    remote = tag_named("remote")

    ruby_and_rails = create_job_lead
    ruby_and_rails.tags = [ ruby, rails ]
    ruby_only = create_job_lead
    ruby_only.tags = [ ruby ]
    remote_only = create_job_lead
    remote_only.tags = [ remote ]

    with_ruby = JobLead.with_tag("ruby")
    assert_includes with_ruby, ruby_and_rails
    assert_includes with_ruby, ruby_only

    assert_includes JobLead.with_tags(%w[ruby rails]), ruby_and_rails

    any_tags = JobLead.with_any_tags(%w[ruby remote])
    assert_includes any_tags, ruby_and_rails
    assert_includes any_tags, ruby_only
    assert_includes any_tags, remote_only
  end

  test "tag scopes return none for empty tag collections" do
    create_job_lead.tags = [ tag_named("empty-check") ]

    assert_empty JobLead.with_tags([])
    assert_empty JobLead.with_any_tags([])
  end

  test "order_by_latest_status sorts by each lead latest status timestamp" do
    freeze_time

    JobLead.destroy_all

    lead = create_job_lead(created_at: 6.days.ago)
    applied = create_job_lead(applied_at: 5.days.ago)
    interview = create_job_lead
    create_interview(job_lead: interview, scheduled_at: 4.days.ago)
    offer = create_job_lead(offer_amount: 120_000, offer_at: 3.days.ago)
    rejected = create_job_lead(rejected_at: 2.days.ago)
    accepted = create_job_lead(accepted_at: 1.day.ago)

    expected = [ lead, applied, interview, offer, rejected, accepted ].map(&:id)

    assert_equal expected, JobLead.order_by_latest_status(:asc).pluck(:id)
    assert_equal expected.reverse, JobLead.order_by_latest_status(:desc).pluck(:id)
  end

  test "should infer status correctly and expose predicate methods" do
    freeze_time

    lead = create_job_lead
    assert_status lead, "lead"

    lead.applied!
    assert_status lead.reload, "applied"

    create_interview(job_lead: lead, scheduled_at: 1.day.from_now)
    assert_status lead.reload, "interview"

    lead.update!(offer_amount: 100_000, offer_at: Time.current)
    assert_status lead.reload, "offer"

    lead.rejected!
    assert_status lead.reload, "rejected"

    lead.accepted_at = Time.current
    assert_status lead, "accepted"
  end

  test "should return previous status from the chronological status timeline" do
    user = users(:one)

    lead = user.job_leads.create(title: "Example", company: "Example co.", application_url: unique_application_url)
    assert_equal "lead", lead.status
    assert_nil lead.previous_status

    lead.applied!
    assert_equal "applied", lead.status
    assert_equal "lead", lead.previous_status

    # travel 3 days so that `interview.scheduled_at` is in the future
    travel 3.days

    lead.interviews.create!(interviewer: "John Doe", scheduled_at: Time.current)
    assert_equal "interview", lead.status
    assert_equal "applied", lead.previous_status

    # travel 1 week so that `offer_at` is after the interview
    travel 1.week

    lead.update(offer_amount: 100_000, offer_at: Time.current)
    assert_equal "offer", lead.status
    assert_equal "interview", lead.previous_status

    lead.accepted!
    assert_equal "accepted", lead.status
    assert_equal "offer", lead.previous_status

    lead.update!(accepted_at: nil)
    lead.rejected!
    assert_equal "rejected", lead.status
    assert_equal "offer", lead.previous_status
  end

  test "status bang methods set timestamps and persist changes" do
    freeze_time

    @user.update_settings(archiving: { rejected: { enabled: false } })
    lead = create_job_lead

    assert lead.applied!
    assert_equal Time.current.to_i, lead.reload.applied_at.to_i

    lead.offer_amount = 100_000
    assert lead.offer!
    assert_equal Time.current.to_i, lead.reload.offer_at.to_i

    assert lead.accepted!
    assert_equal Time.current.to_i, lead.reload.accepted_at.to_i

    rejected_lead = create_job_lead
    assert rejected_lead.rejected!
    assert_equal Time.current.to_i, rejected_lead.reload.rejected_at.to_i
  end

  test "offer bang requires an offer amount" do
    error = assert_raises(ActiveRecord::RecordInvalid) { create_job_lead.offer! }

    assert_includes error.record.errors[:base], "cannot advance to Offer without specifying an offer amount"
  end

  test "updating offer amount advances lead to offer" do
    freeze_time

    lead = create_job_lead

    assert lead.update!(offer_amount: 100_000)

    assert_equal "offer", lead.reload.status
    assert_equal Time.current.to_i, lead.offer_at.to_i
  end

  test "rejected! archives when rejected auto-archiving is enabled" do
    freeze_time

    @user.update_settings(archiving: { rejected: { enabled: true } })
    lead = create_job_lead

    assert lead.rejected!

    assert lead.reload.archived?
    assert_equal Time.current.to_i, lead.archived_at.to_i
  end

  test "rejected! leaves lead active when rejected auto-archiving is disabled" do
    @user.update_settings(archiving: { rejected: { enabled: false } })
    lead = create_job_lead

    assert lead.rejected!
    assert lead.reload.active?
  end

  test "should enforce single terminal status" do
    @lead.accepted_at = Time.current
    @lead.rejected_at = Time.current

    assert_not @lead.valid?
    assert_includes @lead.errors[:base], "cannot be both rejected and accepted"
  end

  test "should require offer amount if offer_at is present" do
    @lead.offer_at = Time.current
    @lead.offer_amount = nil

    assert_not @lead.valid?
    assert_includes @lead.errors[:base], "cannot advance to Offer without specifying an offer amount"
  end

  test "last_interview_at and next_interview_at return nearest past and future interviews" do
    freeze_time

    lead = create_job_lead
    assert_nil lead.last_interview_at
    assert_nil lead.next_interview_at

    oldest_past = create_interview(job_lead: lead, scheduled_at: 3.days.ago)
    newest_past = create_interview(job_lead: lead, scheduled_at: 1.day.ago)
    nearest_future = create_interview(job_lead: lead, scheduled_at: 1.day.from_now)
    create_interview(job_lead: lead, scheduled_at: 3.days.from_now)

    assert_equal newest_past.scheduled_at, lead.last_interview_at
    assert_equal nearest_future.scheduled_at, lead.next_interview_at
    assert_not_equal oldest_past.scheduled_at, lead.last_interview_at
  end

  test "latest_status_at returns the timestamp for the inferred status" do
    freeze_time

    lead = create_job_lead(created_at: 6.days.ago)
    applied = create_job_lead(applied_at: 5.days.ago)
    interview = create_job_lead
    future_interview = create_interview(job_lead: interview, scheduled_at: 1.day.from_now)
    create_interview(job_lead: interview, scheduled_at: 1.day.ago)
    offer = create_job_lead(offer_amount: 120_000, offer_at: 3.days.ago)
    rejected = create_job_lead(rejected_at: 2.days.ago)
    accepted = create_job_lead(accepted_at: 1.day.ago)

    {
      lead =>      lead.created_at,
      applied =>   applied.applied_at,
      interview => future_interview.scheduled_at,
      offer =>     offer.offer_at,
      rejected =>  rejected.rejected_at,
      accepted =>  accepted.accepted_at
    }.each do |record, expected_status_at|
      assert_equal expected_status_at, record.latest_status_at
    end
  end

  test "latest_status_at uses the last past interview when no future interview exists" do
    freeze_time

    lead = create_job_lead
    create_interview(job_lead: lead, scheduled_at: 3.days.ago)
    latest_past = create_interview(job_lead: lead, scheduled_at: 1.day.ago)

    assert_equal latest_past.scheduled_at, lead.latest_status_at
  end

  test "source_quality returns the quality for the inferred status" do
    assert_equal JobLead.status_quality(:accepted), build_job_lead(accepted_at: Time.current).source_quality
  end

  test "status_quality accepts strings and symbols and returns nil for unknown statuses" do
    assert_equal 50, JobLead.status_quality(:interview)
    assert_equal 50, JobLead.status_quality("interview")
    assert_nil JobLead.status_quality("missing")
  end

  test "archive and unarchive update archived state and type" do
    freeze_time

    lead = create_job_lead

    assert lead.active?
    assert_not lead.archived?
    assert_equal "active", lead.type

    assert lead.archive!
    assert lead.reload.archived?
    assert_equal "archived", lead.type
    assert_equal Time.current.to_i, lead.archived_at.to_i

    assert lead.unarchive!
    assert lead.reload.active?
    assert_equal "active", lead.type
    assert_nil lead.archived_at
  end

  test "stale? uses a strict user stale cutoff" do
    freeze_time

    @user.update_settings(archiving: { stale: { mark_after_days: 7 } })
    old = create_job_lead(created_at: 8.days.ago)
    boundary = create_job_lead(created_at: 7.days.ago)
    recent = create_job_lead(created_at: 6.days.ago)

    assert old.stale?
    assert_not boundary.stale?
    assert_not recent.stale?
  end

  test "tag_list returns comma separated tag names" do
    lead = create_job_lead
    lead.tags = [ tag_named("alpha"), tag_named("beta") ]

    assert_equal %w[alpha beta], lead.tag_list.split(", ").sort
    assert_equal "", create_job_lead.tag_list
  end

  test "tag_list setter stores normalized pending tag names" do
    lead = create_job_lead
    lead.tag_list = " Fake, Tags, fake, , Right  Here "

    assert_equal [ "fake", "tags", "right  here" ], lead.pending_tag_names
  end

  test "should assign tags after save" do
    lead = create_job_lead
    lead.tag_list = "Fake, Tags, Right, Here"

    assert_difference -> { lead.user.tags.count }, 4 do
      lead.save!
    end
    assert_equal %w[fake here right tags], lead.tags.pluck(:name).sort
  end

  test "status_history returns ordered timeline with interviews and excludes nil timestamps" do
    user = users(:one)

    lead = user.job_leads.create!(
      title: "Example",
      company: "Example Co.",
      application_url: unique_application_url,
      created_at: 1.day.ago,
      applied_at: 23.hours.ago,
      offer_at: nil,
      accepted_at: nil,
      rejected_at: nil
    )

    interview1 = lead.interviews.create!(interviewer: "A", scheduled_at: 12.hours.ago)
    interview2 = lead.interviews.create!(interviewer: "B", scheduled_at: 6.hours.ago)

    history = lead.status_history

    assert_equal %w[lead applied interview interview], history.map { _1[:status] }

    assert_equal lead.created_at, history[0][:timestamp]
    assert_equal lead.applied_at, history[1][:timestamp]

    assert_equal interview1, history[2][:interview]
    assert_equal interview2, history[3][:interview]

    assert history.none? { _1[:timestamp].nil? }
  end

  test "top_sources_by_quality returns expected structure and sorts correctly" do
    user = users(:one)
    JobLead.destroy_all

    user.job_leads.create!(
      title: "Lead 1", company: "Co", application_url: unique_application_url, source: "LinkedIn",
      applied_at: Time.current
    )

    user.job_leads.create!(
      title: "Lead 2", company: "Co", application_url: unique_application_url, source: "LinkedIn",
      applied_at: Time.current, offer_amount: 100_000, offer_at: Time.current
    )

    user.job_leads.create!(
      title: "Lead 3", company: "Co", application_url: unique_application_url, source: "Indeed",
      applied_at: Time.current
    )

    lead_with_interview = user.job_leads.create!(
      title: "Lead 4", company: "Co", application_url: unique_application_url, source: "Indeed",
      applied_at: Time.current
    )
    lead_with_interview.interviews.create!(interviewer: "John Doe", scheduled_at: 1.day.from_now)

    user.job_leads.create!(
      title: "Lead 5", company: "Co", application_url: unique_application_url, source: "Indeed",
      applied_at: Time.current, rejected_at: Time.current
    )

    user.job_leads.create!(
      title: "Lead 6", company: "Co", application_url: unique_application_url, source: "Glassdoor",
      applied_at: Time.current
    )

    top_sources = user.job_leads.top_sources_by_quality

    assert_equal %w[LinkedIn Indeed], top_sources.keys

    assert_equal 2, top_sources["LinkedIn"][:lead_count]
    assert_equal 1, top_sources["LinkedIn"][:offer_count]
    assert_equal 0, top_sources["LinkedIn"][:interview_count]

    assert_equal 3, top_sources["Indeed"][:lead_count]
    assert_equal 0, top_sources["Indeed"][:offer_count]
    assert_equal 1, top_sources["Indeed"][:interview_count]

    assert_nil top_sources["Glassdoor"]
  end

  test "top_sources_by_quality ignores blank sources, normalizes casing, and respects limit" do
    JobLead.destroy_all

    create_job_lead(source: nil, applied_at: Time.current)
    create_job_lead(source: "", applied_at: Time.current)
    create_job_lead(source: "LinkedIn", accepted_at: Time.current)
    create_job_lead(source: "LinkedIn", accepted_at: Time.current)
    linked_in_offer = create_job_lead(source: "linkedin", applied_at: Time.current, offer_amount: 100_000, offer_at: Time.current)
    create_job_lead(source: "Indeed", accepted_at: Time.current)
    create_job_lead(source: "Referral", accepted_at: Time.current)

    top_sources = JobLead.top_sources_by_quality(2)

    assert_equal 2, top_sources.size
    assert_includes top_sources.keys, "LinkedIn"
    assert_not_includes top_sources.keys, nil
    assert_not_includes top_sources.keys, ""
    assert_equal 3, top_sources["LinkedIn"][:lead_count]
    assert_equal 1, top_sources["LinkedIn"][:offer_count]
    assert_equal 2, top_sources["LinkedIn"][:accepted_count]
    assert linked_in_offer.offer?
  end

  test "cleanup_stale archives stale lead-status records at the cleanup cutoff" do
    freeze_time

    @user.update_settings(archiving: { stale: { mark_after_days: 7 } })
    JobLead.destroy_all
    cutoff = 28.days.ago

    stale = create_job_lead(created_at: 29.days.ago)
    boundary = create_job_lead(created_at: cutoff)
    active_recent = create_job_lead(created_at: 27.days.ago)
    applied = create_job_lead(created_at: 29.days.ago, applied_at: 29.days.ago)

    JobLead.cleanup_stale(@user, cutoff)

    assert stale.reload.archived?
    assert boundary.reload.archived?
    assert active_recent.reload.active?
    assert applied.reload.active?
  end

  test "cleanup_inactive archives user leads updated at or before the cleanup cutoff" do
    freeze_time

    JobLead.destroy_all
    cutoff = 28.days.ago

    inactive = create_job_lead(updated_at: 29.days.ago)
    boundary = create_job_lead(updated_at: cutoff)
    active_recent = create_job_lead(updated_at: 27.days.ago)
    other_user_lead = create_job_lead(user: users(:two), updated_at: 29.days.ago)

    JobLead.cleanup_inactive(@user, cutoff)

    assert inactive.reload.archived?
    assert boundary.reload.archived?
    assert active_recent.reload.active?
    assert other_user_lead.reload.active?
  end

  test "cleanup_for_user respects disabled auto archive settings" do
    freeze_time

    @user.update_settings(archiving: { stale: { enabled: false } })
    @user.update_settings(archiving: { inactive: { enabled: false } })
    JobLead.destroy_all
    old = create_job_lead(created_at: 40.days.ago, updated_at: 40.days.ago)

    JobLead.cleanup_for_user(@user)

    assert old.reload.active?
  end

  test "cleanup_for_user archives enabled stale and inactive leads" do
    freeze_time

    @user.update_settings(archiving: { stale: { enabled: true } })
    @user.update_settings(archiving: { stale: { mark_after_days: 7 } })
    @user.update_settings(archiving: { stale: { archive_after_days: 21 } })
    @user.update_settings(archiving: { inactive: { enabled: true } })
    @user.update_settings(archiving: { inactive: { after_days: 28 } })
    JobLead.destroy_all

    stale = create_job_lead(created_at: 29.days.ago, updated_at: 1.day.ago)
    inactive = create_job_lead(applied_at: 1.day.ago, created_at: 1.day.ago, updated_at: 29.days.ago)
    recent = create_job_lead(created_at: 27.days.ago, updated_at: 27.days.ago)

    JobLead.cleanup_for_user(@user)

    assert stale.reload.archived?
    assert inactive.reload.archived?
    assert recent.reload.active?
  end

  private

  def assert_status(lead, expected_status)
    assert_equal expected_status, lead.inferred_status
    assert_equal expected_status, lead.status

    JobLead::STATUSES.each do |status|
      assert_equal expected_status == status, lead.public_send("#{status}?"), "#{status}? predicate mismatch"
    end
  end

  def tag_named(name)
    @user.tags.find_or_create_by!(name:)
  end
end
