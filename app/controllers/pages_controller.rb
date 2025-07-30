class PagesController < ApplicationController
  before_action :cleanup_leads, only: :home

  def home
    @all_job_leads = Current.user.job_leads.includes(:notes, :tags)
    @all_interviews = Current.user.interviews.includes(:job_lead)
    @all_notes = Current.user.notes.includes(notable: :job_lead)

    this_week = Time.current.all_week
    last_week = Time.current.last_week.all_week

    @job_leads_this_week_count = @all_job_leads.where(created_at: this_week).count
    @job_leads_last_week_count = @all_job_leads.where(created_at: last_week).count

    @applications_this_week_count = @all_job_leads.applied.where(applied_at: this_week).count
    @applications_last_week_count = @all_job_leads.applied.where(applied_at: last_week).count

    @interviews_this_week_count = @all_interviews.where(scheduled_at: this_week).count
    @interviews_last_week_count = @all_interviews.where(scheduled_at: last_week).count

    applied_leads = @all_job_leads.application_follow_up_for_user(Current.user)
    interviewed_leads = @all_job_leads.interview_follow_up_for_user(Current.user)

    @follow_up_suggestions = (applied_leads + interviewed_leads).sort_by(&:latest_status_at).reverse

    @stale_leads = @all_job_leads.stale_for_user(Current.user).order(updated_at: :asc)
    @interviews_upcoming = @all_interviews.upcoming.order(scheduled_at: :asc)
    @recent_notes = @all_notes.recent.order(updated_at: :desc).limit(10)

    @top_sources = @all_job_leads.top_sources_by_quality
    @top_tags = Current.user.tags.top_by_usage.limit(20).pluck(:name)
  end

  private

  def cleanup_leads
    JobLead.cleanup_for_user(Current.user)
  end
end
