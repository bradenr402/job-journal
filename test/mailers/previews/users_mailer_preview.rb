# Preview all emails at http://localhost:3001/rails/mailers/users_mailer
class UsersMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3001/rails/mailers/users_mailer/email_changed
  def email_changed
    UsersMailer.email_changed(User.take, previous_email: "old@example.com")
  end
end
