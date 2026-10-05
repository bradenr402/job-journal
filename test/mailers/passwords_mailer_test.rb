require "test_helper"

class PasswordsMailerTest < ActionMailer::TestCase
  test "reset links to the reset page in both parts" do
    mail = PasswordsMailer.reset(users(:one))

    assert_equal [ "one@example.com" ], mail.to
    assert_equal "Reset your JobJournal password", mail.subject
    assert_match "/passwords/", mail.text_part.body.to_s
    assert_match "/passwords/", mail.html_part.body.to_s
  end
end
