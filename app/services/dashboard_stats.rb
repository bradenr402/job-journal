class DashboardStats
  Stats = Struct.new(
    :all_job_leads,
    :all_interviews,
    :all_notes,
    :job_leads_this_week_count,
    :job_leads_last_week_count,
    :applications_this_week_count,
    :applications_last_week_count,
    :interviews_this_week,
    :interviews_this_week_count,
    :interviews_last_week_count,
    :follow_up_suggestions,
    :stale_leads,
    :upcoming_interviews,
    :recent_interviews,
    :recent_notes,
    :top_sources,
    :top_tags,
    keyword_init: true
  )

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def all_job_leads
    @all_job_leads ||= user.job_leads.includes(:notes, :tags)
  end

  def all_interviews
    @all_interviews ||= user.interviews.includes(:job_lead)
  end

  def all_notes
    @all_notes ||= user.notes.includes(notable: :job_lead)
  end

  def stats
    return Stats.new(all_job_leads:) if all_job_leads.empty?

    this_week = Time.current.all_week
    last_week = Time.current.last_week.all_week

    Stats.new(
      all_job_leads:,
      all_interviews:,
      all_notes:,
      job_leads_this_week_count: all_job_leads.where(created_at: this_week).size,
      job_leads_last_week_count: all_job_leads.where(created_at: last_week).size,
      applications_this_week_count: all_job_leads.where(applied_at: this_week).size,
      applications_last_week_count: all_job_leads.where(applied_at: last_week).size,
      interviews_this_week: all_interviews.where(scheduled_at: this_week),
      interviews_this_week_count: all_interviews.where(scheduled_at: this_week).size,
      interviews_last_week_count: all_interviews.where(scheduled_at: last_week).size,
      follow_up_suggestions: follow_up_suggestions,
      stale_leads: all_job_leads.stale_for_user(user).order(updated_at: :asc),
      upcoming_interviews: all_interviews.upcoming.order(scheduled_at: :asc),
      recent_interviews: recent_interviews,
      recent_notes: all_notes.recent.order(updated_at: :desc).limit(15),
      top_sources: all_job_leads.top_sources_by_quality,
      top_tags: user.tags.top_by_usage.limit(20).pluck(:name)
    )
  end

  private

  def follow_up_suggestions
    applied_leads = all_job_leads.application_follow_up_for_user(user)
    interviewed_leads = all_job_leads.interview_follow_up_for_user(user)
    (applied_leads + interviewed_leads).sort_by(&:latest_status_at).reverse
  end

  def recent_interviews
    recent = all_interviews.recent
    interviews_no_rating = recent.where(rating: nil)
    interviews_no_notes = recent.where.not(
      id: recent
        .joins(:notes)
        .where('notes.updated_at >= interviews.scheduled_at')
        .distinct
        .select(:id)
    )
    interviews_no_rating.or(interviews_no_notes).distinct.order(scheduled_at: :desc)
  end
end
