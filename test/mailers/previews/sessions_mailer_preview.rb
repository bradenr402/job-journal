# Preview all emails at http://localhost:3000/rails/mailers/sessions_mailer
class SessionsMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/sessions_mailer/new_login
  def new_login
    SessionsMailer.new_login(Session.take)
  end
end
