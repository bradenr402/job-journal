class UsersMailer < ApplicationMailer
  # Sent to the previous address so the owner learns about the change even if
  # someone else made it.
  def email_changed(user, previous_email:)
    @user = user
    @previous_email = previous_email
    mail subject: "Your JobJournal email address was changed", to: previous_email
  end
end
