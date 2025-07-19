class PagesController < ApplicationController
  def home
    @all_job_leads = Current.user.job_leads.includes(:notes, :tags)
    @all_interviews = Current.user.interviews.includes(:job_lead)
    @all_notes = Current.user.notes.includes(notable: :job_lead)

    this_week = Time.current.all_week
    last_week = Time.current.last_week.all_week

    @job_leads_this_week = @all_job_leads.where(created_at: this_week)
    @job_leads_last_week = @all_job_leads.where(created_at: last_week)

    @interviews_this_week = @all_interviews.where(scheduled_at: this_week)
    @interviews_last_week = @all_interviews.where(scheduled_at: last_week)

    @stale_leads = @all_job_leads.lead.stale.order(updated_at: :asc)
    @interviews_upcoming = @all_interviews.upcoming.order(scheduled_at: :asc)
    @recent_notes = @all_notes.recent.order(updated_at: :desc).limit(10)

    @top_sources = @all_job_leads.top_sources_by_quality
    @top_tags = Current.user.tags.top_by_usage.limit(15).pluck(:name)
  end
end
