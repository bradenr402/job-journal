class PagesController < ApplicationController
  before_action :cleanup_leads, only: :home

  def home
    stats = DashboardStats.new(Current.user).stats
    stats.each_pair { |key, value| instance_variable_set("@#{key}", value) }
  end

  def security
    @sessions = Current.user.sessions.order(updated_at: :desc)
    @agent = PasskeysRails::Agent.find_by(authenticatable: Current.user)
    @passkeys = @agent&.passkeys || []
  end

  private

  def cleanup_leads
    JobLead.cleanup_for_user(Current.user)
  end
end
