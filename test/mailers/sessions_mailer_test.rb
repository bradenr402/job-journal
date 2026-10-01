require "test_helper"

class SessionsMailerTest < ActionMailer::TestCase
  test "new_login describes the session" do
    session = users(:one).sessions.create!(
      ip_address: "203.0.113.7",
      user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
    )

    mail = SessionsMailer.new_login(session)

    assert_equal [ "one@example.com" ], mail.to
    assert_equal "New sign-in to your JobJournal account", mail.subject
    assert_match "Desktop · Mac", mail.text_part.body.to_s
    assert_match "Chrome", mail.text_part.body.to_s
    assert_match "203.0.113.7", mail.html_part.body.to_s
    assert_match "/security", mail.html_part.body.to_s
  end
end
