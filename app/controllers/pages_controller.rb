class PagesController < ApplicationController
  allow_unauthenticated_access only: :landing
  layout "landing", only: :landing

  before_action :cleanup_leads, only: :home

  def landing
    @demo = LandingDemo.new
  end

  def home
    stats = DashboardStats.new(Current.user).stats
    stats.each_pair { |key, value| instance_variable_set("@#{key}", value) }
  end

  def security
    @sessions = Current.user.sessions.order(updated_at: :desc)
    @session_groups = group_sessions_by_recency(@sessions)
  end

  private

  # Returns [[mark, sessions], ...] where mark is the time boundary preceding
  # the group: nil for the current session and those seen in the past week, or
  # a Session::RECENCY_MARKS key for sessions inactive longer than that mark.
  def group_sessions_by_recency(sessions)
    current, others = sessions.partition { |session| session == Current.session }
    marks = Session::RECENCY_MARKS.to_a

    groups = others.group_by do |session|
      marks.rindex { |_, duration| session.updated_at < duration.ago }
    end

    [
      [ nil, current + groups.fetch(nil, []) ],
      *marks.each_with_index.map { |(mark, _), index| [ mark, groups[index] ] }
    ].select { |_, group| group.present? }
  end

  def cleanup_leads
    JobLead.cleanup_for_user(Current.user)
  end
end
