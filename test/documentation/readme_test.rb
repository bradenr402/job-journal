require "test_helper"

class ReadmeTest < ActiveSupport::TestCase
  test "README mentions every supported autofill source" do
    readme = Rails.root.join("README.md").read

    Constants::SUPPORTED_AUTOFILL_SOURCES.each do |source|
      assert_includes readme, "**#{source}**", "README.md is missing autofill source #{source.inspect}.  Update the Autofill From URL section to list all supported sources."
    end
  end
end
