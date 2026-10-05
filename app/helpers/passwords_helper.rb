module PasswordsHelper
  def masked_email(email)
    local, domain = email.split("@", 2)
    "#{local.first}#{"•" * 3}@#{domain}"
  end
end
