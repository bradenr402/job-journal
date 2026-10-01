require "test_helper"

class UsersMailerTest < ActionMailer::TestCase
  test "email_changed notifies the previous address" do
    user = users(:one)

    mail = UsersMailer.email_changed(user, previous_email: "old@example.com")

    assert_equal [ "old@example.com" ], mail.to
    assert_equal "Your JobJournal email address was changed", mail.subject
    assert_match user.email_address, mail.text_part.body.to_s
    assert_match "/security", mail.html_part.body.to_s
  end
end
