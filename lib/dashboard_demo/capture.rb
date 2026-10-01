require "action_dispatch/testing/integration"

module DashboardDemo
  # Seeds the demo data, renders the real dashboard for that user through the
  # full Rails stack, and rolls everything back. Returns the page's HTML.
  class Capture
    include ActiveSupport::Testing::TimeHelpers

    HOST = "localhost".freeze

    def initialize(data)
      @data = data
    end

    def call
      html = nil

      # Wrapping in the executor keeps the request below from releasing the
      # connection (and our open transaction) when it finishes.
      Rails.application.executor.wrap do
        travel_to(now) do
          ActiveRecord::Base.transaction do
            user = Seed.new(@data, now:).call
            html = render_dashboard_for(user)
            raise ActiveRecord::Rollback
          end
        end
      end

      html
    end

    private

    def now
      @now ||= begin
        config = @data.fetch("now")
        weekday = Date::DAYNAMES.index(config.fetch("weekday").capitalize) or raise ArgumentError, "Unknown weekday: #{config['weekday']}"
        hour, minute = config.fetch("time").split(":").map(&:to_i)

        week_start = Time.current.beginning_of_week(:sunday)
        week_start.advance(days: weekday).change(hour:, min: minute)
      end
    end

    def render_dashboard_for(user)
      app_session = user.sessions.create!(user_agent: "DashboardDemo", ip_address: "127.0.0.1")

      request = ActionDispatch::Integration::Session.new(Rails.application)
      request.host! HOST
      request.cookies[Authentication::SESSION_COOKIE_NAME.to_s] = signed_session_cookie(app_session)
      request.get "/dashboard"

      unless request.response.successful?
        raise "Rendering the dashboard failed (HTTP #{request.response.status}): #{request.response.location || request.response.body.truncate(500)}"
      end

      request.response.body
    end

    def signed_session_cookie(app_session)
      name = Authentication::SESSION_COOKIE_NAME.to_s
      jar = ActionDispatch::Request.new(Rails.application.env_config.merge("HTTP_HOST" => HOST)).cookie_jar
      jar.signed[name] = app_session.id
      jar[name]
    end
  end
end
