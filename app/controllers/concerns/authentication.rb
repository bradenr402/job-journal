module Authentication
  extend ActiveSupport::Concern
  SESSION_COOKIE_NAME = :job_journal_session_id

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      Session.find_by(id: cookies.signed[SESSION_COOKIE_NAME]) if cookies.signed[SESSION_COOKIE_NAME]
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      flash[:alert] = "You must be logged in to access this page"
      redirect_to new_session_path
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || dashboard_url
    end

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[SESSION_COOKIE_NAME] = { value: session.id, httponly: true, same_site: :lax }
      end
    end

    def terminate_session(session = Current.session)
      session.destroy
      cookies.delete(SESSION_COOKIE_NAME) if session == Current.session
    end
end
