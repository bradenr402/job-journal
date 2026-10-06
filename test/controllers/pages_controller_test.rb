require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get landing page when not signed in" do
    get root_url
    assert_response :success
  end

  test "should show every feature tile on the landing page" do
    get root_url

    [ "Job Lead Management", "Autofill From URL", "Interview Tracking", "Installable App", "Smart Search & Filters", "Tags", "Account Security" ].each do |title|
      assert_select ".bento-grid h3", title
    end
    assert_select ".bento-grid", text: /Works with #{Constants::SUPPORTED_AUTOFILL_SOURCES.to_sentence}/
  end

  test "should show records in the feature tiles that differ from the other demos" do
    get root_url

    assert_select ".bento-grid", text: /Product Engineer/
    assert_select ".bento-grid", text: /Interview with Priya Patel/
    assert_select ".bento-grid", text: /Stripe|Vercel|Sarah Chen/, count: 0
  end

  test "should separate landing page sections with dividers" do
    get root_url

    assert_select "main.landing-section-dividers"
  end

  test "should get landing page when signed in" do
    sign_in_as users(:one)
    get root_url
    assert_response :success
  end

  test "should get dashboard when signed in" do
    sign_in_as users(:one)
    get dashboard_url
    assert_response :success
  end

  test "should redirect to sign in when accessing dashboard unauthenticated" do
    get dashboard_url
    assert_redirected_to new_session_url
  end

  test "should embed icons JSON" do
    sign_in_as users(:one)
    get dashboard_url

    match = response.body.match(/window\.JobJournal\.icons\s*=\s*(?<icons>\{.*\});/m)
    assert match, "Expected window.JobJournal.icons assignment"

    icons = JSON.parse match[:icons]

    assert_equal icons, JOB_JOURNAL_ICONS.as_json, "Expected embedded icons JSON to match JOB_JOURNAL_ICONS"
  end

  test "security page groups sessions by last seen" do
    user = users(:one)
    user.sessions.delete_all
    post session_url, params: { email_address: user.email_address, password: "password" }

    { 3.days => "recent", 2.weeks => "week", 2.months => "month", 4.months => "quarter", 1.year => "old" }.each do |age, name|
      user.sessions.create!(user_agent: name).update_columns(updated_at: age.ago)
    end

    get security_url

    assert_response :success
    labels = css_select("span.text-xs.font-medium").map { it.text.strip }
    assert_equal [ "1 Week – 1 Month Ago", "1–3 Months Ago", "3–6 Months Ago", "Over 6 Months Ago" ], labels
    groups = css_select("ul").select { |ul| ul.at_css("> li[style*='session-']") }
    assert_equal [ 2, 1, 1, 1, 1 ], groups.map { it.css("> li").size }
  end

  test "security page skips empty groups" do
    user = users(:one)
    user.sessions.delete_all
    post session_url, params: { email_address: user.email_address, password: "password" }
    user.sessions.create!.update_columns(updated_at: 1.year.ago)

    get security_url

    assert_select "form[action=?]", destroy_inactive_sessions_path(since: "6_months")
    assert_select "form[action=?]", destroy_inactive_sessions_path(since: "1_week"), count: 0
  end
end
