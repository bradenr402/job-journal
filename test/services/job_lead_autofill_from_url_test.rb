require "test_helper"
require "minitest/mock"

class JobLeadAutofillFromUrlTest < ActiveSupport::TestCase
  # --- URL safety check -----------------------------------------------------
  test "safe_url? rejects unsupported hosts" do
    assert_not JobLeadAutofillFromUrl.safe_url?("https://example.com/jobs/123")
  end

  test "safe_url? rejects non-http schemes" do
    assert_not JobLeadAutofillFromUrl.safe_url?("javascript:alert(1)")
    assert_not JobLeadAutofillFromUrl.safe_url?("file:///etc/passwd")
  end

  test "safe_url? rejects malformed URLs" do
    assert_not JobLeadAutofillFromUrl.safe_url?("not a url")
    assert_not JobLeadAutofillFromUrl.safe_url?("")
    assert_not JobLeadAutofillFromUrl.safe_url?(nil)
  end

  test "safe_url? accepts a public LinkedIn https URL" do
    with_resolution("www.linkedin.com" => %w[151.101.1.1]) do
      assert JobLeadAutofillFromUrl.safe_url?("https://www.linkedin.com/jobs/view/123/")
    end
  end

  test "safe_url? rejects hosts that resolve to loopback (SSRF guard)" do
    with_resolution("www.linkedin.com" => %w[127.0.0.1]) do
      assert_not JobLeadAutofillFromUrl.safe_url?("https://www.linkedin.com/jobs/view/123/")
    end
  end

  test "safe_url? rejects hosts that resolve to private RFC1918 ranges (SSRF guard)" do
    with_resolution("www.linkedin.com" => %w[10.0.0.5]) do
      assert_not JobLeadAutofillFromUrl.safe_url?("https://www.linkedin.com/jobs/view/123/")
    end
  end

  # --- Successful parse path ------------------------------------------------
  test "call returns parsed fields for a LinkedIn page" do
    expected = JSON.parse(file_fixture("junior_developer_collabera.json").read, symbolize_names: true)

    with_resolution("www.linkedin.com" => %w[151.101.1.1]) do
      with_http_response(file_fixture("junior_developer_collabera.html").read) do
        result = JobLeadAutofillFromUrl.call("https://www.linkedin.com/jobs/view/4404473006")

        assert_predicate result, :success?
        expected.each do |key, value|
          actual = result.fields[key]
          if value.is_a?(Array)
            assert_equal value.sort, Array(actual).sort
          else
            assert_equal value, actual
          end
        end
      end
    end
  end

  test "call returns failure for unsupported hosts without making a network request" do
    Net::HTTP.stub :start, ->(*) { raise "should not be called" } do
      result = JobLeadAutofillFromUrl.call("https://example.com/jobs/1")

      assert_not result.success?
      assert result.error.present?
    end
  end

  test "Net::HTTP and Resolv are loaded so the service works at runtime" do
    assert defined?(Net::HTTP), "Net::HTTP must be required"
    assert defined?(Resolv), "Resolv must be required for the SSRF guard to work"
  end

  private

  # --- helpers --------------------------------------------------------------
  def with_resolution(map)
    Resolv.stub(:getaddresses, ->(host) { map[host] || [] }) { yield }
  end

  def with_http_response(body)
    response = Net::HTTPSuccess.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    response.body = body

    fake_start = lambda do |*_args, **_kwargs, &block|
      http = Object.new
      http.define_singleton_method(:request) { |_req| response }
      block ? block.call(http) : http
    end

    Net::HTTP.stub(:start, fake_start) { yield }
  end
end
