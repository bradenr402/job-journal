require "test_helper"

class DashboardDemoTest < ActiveSupport::TestCase
  setup do
    data = YAML.safe_load_file(DashboardDemo::DATA_PATH)
    html = DashboardDemo::Capture.new(data).call
    @demo = DashboardDemo::Normalizer.new(html, css: ".card{}").call
    @document = Nokogiri::HTML5(@demo)
  end

  test "renders the dashboard for the demo user" do
    main = @document.at_css("main").text.squish

    assert_includes main, "Welcome Back, Braden Roth!"
    assert_includes main, "Job Leads This Week 5 +2 from last week"
    assert_includes main, "Interview with Sarah Chen"
    assert_includes main, "Top Sources"
  end

  test "strips everything interactive or identifying" do
    %w[a button form input script iframe link].each do |tag|
      assert_empty @document.css(tag), "Expected no <#{tag}> elements"
    end

    attributes = @document.css("*").flat_map { it.attribute_nodes.map(&:name) }.uniq
    assert_empty attributes.grep(/\Aon|\Ahref\z|\Adata-(controller|action|turbo)/)
    assert_no_match(/<!--/, @demo)
    assert_no_match(/csrf|authenticity_token/, @demo)
  end

  test "keeps hover styles on cards that had covering links" do
    assert @document.css(".card.card-interactive").any?
  end

  test "localizes times like the local_time JavaScript" do
    time = @document.at_css("time[data-local]")

    assert time.key?("data-localized")
    assert_match(/\A\w+ \d+, \d{4} at \d+:\d{2}[ap]m E[SD]T\z/, time["title"])
  end

  test "rolls back the demo records" do
    assert_not User.exists?(name: "Braden Roth", email_address: "demo@jobjournal.app")
  end
end
