require "test_helper"

class LinkedInParserTest < ActiveSupport::TestCase
  FIXTURES_DIR = "linkedin".freeze
  fixture_names = Rails.root.glob("test/fixtures/files/#{FIXTURES_DIR}/*.html").map { it.basename(".html").to_s }

  fixture_names.each do |filename|
    test "extracts expected fields from #{filename}" do
      doc = Nokolexbor::HTML file_fixture("#{FIXTURES_DIR}/#{filename}.html").read
      fields = Parsers::LinkedInParser.new(doc).to_h
      expected = JSON.parse file_fixture("#{FIXTURES_DIR}/#{filename}.json").read, symbolize_names: true

      flunk "Expected fixture is empty.\nActual:\n#{fields.to_json}" if expected.empty?

      expected.each do |key, value|
        actual = fields[key]

        if value.is_a?(Array)
          assert_equal value.sort, actual.sort, "Missing: #{value - actual}, Unexpected: #{actual - value}"
        else
          assert_equal value, actual
        end
      end
    end
  end

  test "returns nil for missing fields without raising" do
    doc = Nokolexbor::HTML('<html><body><h1 class="topcard__title">Just a Title</h1></body></html>')

    fields = Parsers::LinkedInParser.new(doc).to_h

    assert_equal "Just a Title", fields[:title]
    assert_nil fields[:company]
    assert_nil fields[:location]
    assert_nil fields[:application_url]
    assert_equal "LinkedIn", fields[:source]
  end

  test "backfills salary from the description when no salary element is present" do
    html = <<~HTML
      <html><body>
        <h1 class="topcard__title">Engineer</h1>
        <div class="show-more-less-html__markup">
          <p>Compensation: $36,000.00 - $46,000.00 per year</p>
        </div>
      </body></html>
    HTML

    fields = Parsers::LinkedInParser.new(Nokolexbor::HTML(html)).to_h

    assert_equal "$36,000.00 - $46,000.00 per year", fields[:salary]
  end

  test "does not overwrite an existing salary with one from the description" do
    html = <<~HTML
      <html><body>
        <h1 class="topcard__title">Engineer</h1>
        <span class="salary">$50/hr</span>
        <div class="show-more-less-html__markup">
          <p>Compensation: $100,000 per year</p>
        </div>
      </body></html>
    HTML

    fields = Parsers::LinkedInParser.new(Nokolexbor::HTML(html)).to_h

    assert_equal "$50/hr", fields[:salary]
  end
end
