require "test_helper"

class ParsersTest < ActiveSupport::TestCase
  test "registry returns the names of all registered parser classes" do
    assert_equal Parsers.registry, Parsers.constants(false).without(:Base).map(&:to_s).sort
  end

  test "all returns the registered parser classes" do
    assert_equal Parsers.registry, Parsers.all.map { it.name.demodulize }
    assert Parsers.all.all? { it < Parsers::Base }
  end

  test "source_names is derived from each parser's SOURCE_NAME" do
    assert_equal Parsers.source_names, Parsers.all.map { it::SOURCE_NAME }
    assert_includes Parsers.source_names, "LinkedIn"
  end

  test "hosts is the deduplicated union of each parser's ALLOWED_HOSTS" do
    expected = Parsers.all.flat_map { it::ALLOWED_HOSTS }.uniq
    assert_equal Parsers.hosts, expected
    assert_includes Parsers.hosts, "www.linkedin.com"
  end

  test "for_host resolves a parser case-insensitively" do
    assert_equal Parsers::LinkedInParser, Parsers.for_host("www.linkedin.com")
    assert_equal Parsers::IndeedParser, Parsers.for_host("INDEED.COM")
  end

  test "for_host returns nil for unsupported or blank hosts" do
    assert_nil Parsers.for_host("example.com")
    assert_nil Parsers.for_host(nil)
    assert_nil Parsers.for_host("")
  end
end
