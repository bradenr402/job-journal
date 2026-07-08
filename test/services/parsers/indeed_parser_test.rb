require "test_helper"
require "minitest/mock"

class IndeedParserTest < ActiveSupport::TestCase
  FIXTURES_DIR = "indeed".freeze
  fixture_names = Rails.root.glob("test/fixtures/files/#{FIXTURES_DIR}/*.html").map { |path| path.basename(".html").to_s }

  fixture_names.each do |filename|
    test "extracts expected fields from #{filename}" do
      doc = Nokolexbor::HTML file_fixture("#{FIXTURES_DIR}/#{filename}.html").read
      fields = Parsers::IndeedParser.new(doc).to_h
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
    doc = Nokolexbor::HTML('<html><body><h1 class="jobsearch-JobInfoHeader-title">Just a Title</h1></body></html>')

    fields = Parsers::IndeedParser.new(doc).to_h

    assert_equal "Just a Title", fields[:title]
    assert_nil fields[:company]
    assert_nil fields[:location]
    assert_nil fields[:application_url]
    assert_equal "Indeed", fields[:source]
  end

  test "backfills salary from the description when no salary element is present" do
    html = <<~HTML
      <html><body>
        <h1 class="jobsearch-JobInfoHeader-title">Engineer</h1>
        <div id="jobDescriptionText">
          <p>Compensation: $36,000.00 - $46,000.00 per year</p>
        </div>
      </body></html>
    HTML

    fields = Parsers::IndeedParser.new(Nokolexbor::HTML(html)).to_h

    assert_equal "$36,000.00 - $46,000.00 per year", fields[:salary]
  end

  test "does not overwrite an existing salary with one from the description" do
    html = <<~HTML
      <html><body>
        <h1 class="topcard__title">Engineer</h1>
        <span id="salaryInfoAndJobType"><span>$50/hr</span></span>
        <div id="jobDescriptionText">
          <p>Compensation: $36,000.00 - $46,000.00 per year</p>
        </div>
      </body></html>
    HTML

    fields = Parsers::IndeedParser.new(Nokolexbor::HTML(html)).to_h

    assert_equal "$50/hr", fields[:salary]
  end

  test "resolves a confidential company name by following its company page" do
    html = <<~HTML
      <html><body>
        <h1 class="jobsearch-JobInfoHeader-title">Engineer</h1>
        <span data-testid="inlineHeader-companyName">
          <a href="https://www.indeed.com/cmp/Acme-Corp">Confidential</a>
        </span>
      </body></html>
    HTML

    company_page = <<~HTML
      <html><body>
        <div data-testid="cmp-HeaderLayout"><span itemprop="name">Acme Corp</span></div>
      </body></html>
    HTML

    fetcher = lambda do |url, **|
      assert_equal "https://www.indeed.com/cmp/Acme-Corp", url
      company_page
    end

    PageFetcher.stub(:fetch, fetcher) do
      fields = Parsers::IndeedParser.new(Nokolexbor::HTML(html)).to_h
      assert_equal "Acme Corp", fields[:company]
    end
  end

  test "falls back to the confidential label when the company page cannot be fetched" do
    html = <<~HTML
      <html><body>
        <h1 class="jobsearch-JobInfoHeader-title">Engineer</h1>
        <span data-testid="inlineHeader-companyName">
          Confidential <a href="https://www.indeed.com/cmp/Acme-Corp">company</a>
        </span>
      </body></html>
    HTML

    PageFetcher.stub(:fetch, ->(*, **) { nil }) do
      fields = Parsers::IndeedParser.new(Nokolexbor::HTML(html)).to_h
      assert_equal "Confidential company", fields[:company]
    end
  end
end
