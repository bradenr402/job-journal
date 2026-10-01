class SessionsMailer < ApplicationMailer
  def new_login(session)
    @session = session
    @device = DeviceInfo.new(session.user_agent)
    mail subject: "New sign-in to your JobJournal account", to: session.user.email_address
  end
end
