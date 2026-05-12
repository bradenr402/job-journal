require "test_helper"

class LinkedInJobParserTest < ActiveSupport::TestCase
  fixtures = %w[
    junior_developer_collabera
    barista_starbucks_hampton
    nurse_hillsborough
    legal_counsel_revenue_management_solutions
    plumber_tampa_bay_rays
    field_sales_representative_vanta_diagnostics
    graphic_designer_reliaquest
    marketing_manager_accuro_solutions
    chief_executive_officer_encompass_health
  ]

  fixtures.each do |filename|
    test "extracts expected fields from #{filename}" do
      doc = Nokolexbor::HTML file_fixture("#{filename}.html").read
      fields = LinkedInJobParser.new(doc).to_h
      expected = JSON.parse file_fixture("#{filename}.json").read, symbolize_names: true

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

    fields = LinkedInJobParser.new(doc).to_h

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

    fields = LinkedInJobParser.new(Nokolexbor::HTML(html)).to_h

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

    fields = LinkedInJobParser.new(Nokolexbor::HTML(html)).to_h

    assert_equal "$50/hr", fields[:salary]
  end
end
