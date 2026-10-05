class SessionsController < ApplicationController
  layout "auth", only: %i[ new create ]

  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, error: "Try again later." }

  before_action only: %i[new create] do
    redirect_to dashboard_path, notice: "You are already signed in." if authenticated?
  end

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      session = start_new_session_for user
      SessionsMailer.new_login(session).deliver_later
      redirect_to after_authentication_url
    else
      flash.now[:error] = "That email and password don’t match. Please try again."
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    session = params[:session] ? Current.user.sessions.find(params[:session]) : Current.session

    terminate_session session

    if session == Current.session
      redirect_to new_session_path, notice: "You&#8217;ve been signed out."
    else
      redirect_back fallback_location: security_path, notice: "Session successfully terminated."
    end
  end

  def destroy_other_sessions
    count = terminate_sessions Current.user.sessions.where.not(id: Current.session.id)

    redirect_to security_path, notice: termination_notice(count)
  end

  def destroy_inactive_sessions
    mark = params[:since]
    return redirect_to(security_path, error: "Invalid time range.") unless Session::RECENCY_MARKS.key?(mark)

    count = terminate_sessions Current.user.sessions.inactive_since(mark).where.not(id: Current.session.id)

    redirect_to security_path, notice: termination_notice(count, "inactive for over #{mark.humanize(capitalize: false)}")
  end

  private

  def termination_notice(count, qualifier = nil)
    return "No sessions to terminate." if count.zero?

    [ "Terminated #{count} #{"session".pluralize(count)}", qualifier ].compact.join(" ") + "."
  end
end
