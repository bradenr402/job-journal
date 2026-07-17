require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  include InlineSvg::ActionView::Helpers

  setup do
    sign_in_as users(:one)
  end

  teardown do
    Current.reset
  end

  test "resolve_layout returns valid string layouts" do
    assert_equal "grid", resolve_layout("grid")
    assert_equal "list", resolve_layout("list")
    assert_equal "minimal", resolve_layout("minimal")
  end

  test "resolve_layout looks up symbol layouts from current user settings" do
    Current.user.settings = { layouts: { job_leads: "minimal" } }

    assert_equal "minimal", resolve_layout(:job_leads)
  end

  test "resolve_layout uses default user settings for missing symbol settings" do
    Current.user.settings = {}

    assert_equal "grid", resolve_layout(:job_leads)
  end

  test "resolve_layout uses default settings when no current user is present" do
    Current.reset

    assert_equal "grid", resolve_layout(:job_leads)
  end

  test "resolve_layout rejects non string and non symbol layouts" do
    error = assert_raises(ArgumentError) { resolve_layout(nil) }

    assert_equal "Expected layout to be a String or Symbol, got NilClass", error.message
  end

  test "resolve_layout rejects unknown layouts" do
    error = assert_raises(ArgumentError) { resolve_layout("masonry") }

    assert_equal "Unknown layout: \"masonry\". Expected one of: grid, list, minimal", error.message
  end

  test "resolve_layout falls back to default for invalid symbol settings" do
    Current.user.settings = { layouts: { job_leads: "masonry" } }

    assert_equal "grid", resolve_layout(:job_leads)
  end

  test "collection_layout_class_names returns list collection class" do
    assert_equal "card-list", collection_layout_class_names("list", count: 8)
  end

  test "collection_layout_class_names returns minimal collection class" do
    assert_equal "minimal-item-list", collection_layout_class_names("minimal", count: 8)
  end

  test "collection_layout_class_names returns base grid class for small and four item grids" do
    assert_equal "card-grid", collection_layout_class_names("grid", count: 2)
    assert_equal "card-grid", collection_layout_class_names("grid", count: 4)
  end

  test "collection_layout_class_names adds large grid class for three or more items except four" do
    assert_equal "card-grid card-grid-lg", collection_layout_class_names("grid", count: 3)
    assert_equal "card-grid card-grid-lg", collection_layout_class_names("grid", count: 5)
  end

  test "collection_layout_class_names adds medium grid class when requested" do
    assert_equal "card-grid card-grid-md", collection_layout_class_names("grid", count: 3, size: :medium)
  end

  test "collection_layout_class_names skips unknown grid size classes" do
    assert_equal "card-grid", collection_layout_class_names("grid", count: 3, size: :small)
  end

  test "item_layout_class_names returns default item class" do
    assert_equal "card", item_layout_class_names("grid")
    assert_equal "minimal-item", item_layout_class_names("minimal")
  end

  test "page_title defaults to app name" do
    assert_equal "JobJournal", page_title
  end

  test "page_title appends app name when title does not include it" do
    content_for(:title, "Applications")

    assert_equal "Applications • JobJournal", page_title
  end

  test "page_title does not append app name when title already includes it" do
    content_for(:title, "JobJournal Settings")

    assert_equal "JobJournal Settings", page_title
  end

  test "user_setting returns the current user's setting value" do
    Current.user.settings = { layouts: { job_leads: "list" } }

    assert_equal "list", user_setting(:layouts, :job_leads)
  end

  test "number_with_sign prefixes positive and negative numbers" do
    assert_equal "+12.30", number_with_sign(12.3, precision: 2)
    assert_equal "-12.30", number_with_sign(-12.3, precision: 2)
  end

  test "number_with_sign omits zero sign by default" do
    assert_equal "0.0", number_with_sign(0, precision: 1)
  end

  test "number_with_sign uses present zero sign option" do
    assert_equal "±0", number_with_sign(0, precision: 0, zero_sign: "±")
    assert_equal "0", number_with_sign(0, precision: 0, zero_sign: "")
  end

  test "option builds option hashes with defaults" do
    assert_equal({ text: "Job Leads", value: "job_leads", icon: "job_leads" }, option("job_leads"))
  end

  test "option allows custom text and icon" do
    assert_equal({ text: "Leads", value: "job_leads", icon: "briefcase" }, option("job_leads", text: "Leads", icon: "briefcase"))
  end

  test "options builds option hashes for each value" do
    assert_equal [
      { text: "Grid", value: "grid", icon: "grid" },
      { text: "List", value: "list", icon: "list" }
    ], options("grid", "list")
  end

  test "job_lead_count_text pluralizes job leads" do
    assert_equal "1 job lead", job_lead_count_text(1)
    assert_equal "2 job leads", job_lead_count_text(2)
  end

  test "job_lead_count_text prefixes non all type" do
    assert_equal "3 active job leads", job_lead_count_text(3, type: "active")
    assert_equal "3 job leads", job_lead_count_text(3, type: "all")
  end

  test "job_lead_count_text includes status filter" do
    html = job_lead_count_text(2, status: "applied")

    assert html.html_safe?
    assert_includes html, "2 job leads with status:"
    assert_includes html, "<span class=\"font-semibold text-light\">“Applied”</span>"
  end

  test "job_lead_count_text includes singular tag filter" do
    html = job_lead_count_text(2, tags: [ "rails" ])

    assert_includes html, "with tag:"
    assert_includes html, "<span class=\"font-semibold text-light\">rails</span>"
  end

  test "job_lead_count_text includes status and plural tag filters" do
    html = job_lead_count_text(2, type: "active", status: "interview", tags: [ "rails", "remote" ])

    assert_includes html, "2 active job leads with status:"
    assert_includes html, "<span class=\"font-semibold text-light\">“Interview”</span>"
    assert_includes html, "and tags:"
    assert_includes html, "<span class=\"font-semibold text-light\">rails</span>, <span class=\"font-semibold text-light\">remote</span>"
  end

  test "interview_count_text pluralizes interviews" do
    assert_equal "1 interview", interview_count_text(1)
    assert_equal "2 interviews", interview_count_text(2)
  end

  test "interview_count_text prefixes non all type" do
    assert_equal "2 scheduled interviews", interview_count_text(2, type: "scheduled")
    assert_equal "2 interviews", interview_count_text(2, type: "all")
  end

  test "note_count_text pluralizes generic notes" do
    assert_equal "1 note", note_count_text(1)
    assert_equal "2 notes", note_count_text(2)
  end

  test "note_count_text includes humanized notable type" do
    assert_equal "1 job lead note", note_count_text(1, notable: "JobLead")
    assert_equal "2 interview notes", note_count_text(2, notable: :interview)
  end

  test "note_count_text prefixes non all type" do
    assert_equal "2 archived job lead notes", note_count_text(2, type: "archived", notable: "JobLead")
    assert_equal "2 job lead notes", note_count_text(2, type: "all", notable: "JobLead")
  end

  test "line_wrap_url inserts zero width spaces after slashes and hyphens" do
    wrapped = line_wrap_url("https://job-board.com/path-to-role")

    assert wrapped.html_safe?
    assert_equal "https:/\u200B/\u200Bjob-\u200Bboard.com/\u200Bpath-\u200Bto-\u200Brole", wrapped
  end

  test "line_wrap_url returns nil when input is nil" do
    assert_nil line_wrap_url(nil)
  end

  test "url_without_scheme removes http and https schemes" do
    urls = {
      "http://example.com" => "example.com",
      "https://example.com" => "example.com",
      "http://example.com/path/to/resource" => "example.com/path/to/resource",
      "https://example.com/path/to/resource" => "example.com/path/to/resource"
    }

    urls.each do |input, expected|
      assert_equal expected, url_without_scheme(input)
    end
  end

  test "url_without_scheme returns original string when no scheme is present" do
    url_already_without_scheme = "example.com/path/to/resource"

    assert_equal url_already_without_scheme, url_without_scheme(url_already_without_scheme)
  end

  test "url_without_scheme returns nil when input is nil" do
    assert_nil url_without_scheme(nil)
  end

  test "url_without_query removes query parameters from URLs" do
    original_url = "https://example.com/path/to/resource?param1=value1&param2=value2"
    expected_url = "https://example.com/path/to/resource"

    assert_equal expected_url, url_without_query(original_url)
  end

  test "url_without_query returns original string when no query parameters are present" do
    url_already_without_query = "https://example.com/path/to/resource"

    assert_equal url_already_without_query, url_without_query(url_already_without_query)
  end

  test "url_without_query returns nil when input is nil" do
    assert_nil url_without_query(nil)
  end

  test "url_without_scheme_or_query removes both scheme and query parameters from URLs" do
    urls = {
      "http://example.com/path/to/resource?param1=value1&param2=value2" => "example.com/path/to/resource",
      "https://example.com/path/to/resource?param1=value1&param2=value2" => "example.com/path/to/resource"
    }

    urls.each do |input, expected|
      assert_equal expected, url_without_scheme_or_query(input)
    end
  end

  test "url_without_scheme_or_query returns original string when no scheme or query parameters are present" do
    url_already_without_scheme_or_query = "example.com/path/to/resource"

    assert_equal url_already_without_scheme_or_query, url_without_scheme_or_query(url_already_without_scheme_or_query)
  end

  test "url_without_scheme_or_query returns nil when input is nil" do
    assert_nil url_without_scheme_or_query(nil)
  end

  test "display_url returns a line-wrapped URL without scheme or query" do
    original_url = "https://example.com/path/to/resource?param1=value1&param2=value2"
    expected_url = "example.com/\u200Bpath/\u200Bto/\u200Bresource"

    assert_equal expected_url, display_url(original_url)
  end

  test "display_url returns nil when input is nil" do
    assert_nil display_url(nil)
  end

  test "icon returns nil for blank names" do
    assert_nil icon(nil)
    assert_nil icon("")
  end

  test "icon renders existing svg with attributes" do
    html = icon("briefcase", class: "size-4")

    assert_includes html, "<svg"
    assert_includes html, "class=\"size-4\""
  end

  test "icon raises for unknown svg names" do
    error = assert_raises(ArgumentError) { icon("does-not-exist") }

    assert_equal "Unknown icon: \"does-not-exist\" (expected app/assets/images/icons/does-not-exist.svg)", error.message
  end

  test "icon_name_for_status maps known statuses" do
    expected_icons = {
      lead: "briefcase",
      applied: "application",
      interview: "interview",
      offer: "offer",
      accepted: "check-circle",
      rejected: "x-circle"
    }

    expected_icons.each do |status, expected_icon|
      assert_equal expected_icon, icon_name_for_status(status), "Expected #{status.inspect} to map to #{expected_icon.inspect}"
    end
  end

  test "icon_name_for_status raises for unknown statuses" do
    error = assert_raises(ArgumentError) { icon_name_for_status(:unknown_status) }

    assert_equal "Unknown status: :unknown_status. Expected one of: lead, applied, interview, offer, accepted, rejected", error.message
  end

  test "icon_for_status renders the icon for the status" do
    assert_equal icon("application", class: "size-4"), icon_for_status(:applied, class: "size-4")
  end

  test "filter_link renders an unselected filter link" do
    html = filter_link(path: "/job_leads?status=applied", value: "applied", icon_name: "briefcase", selected: false)

    assert_includes html, "href=\"/job_leads?status=applied\""
    assert_includes html, "<span>Applied</span>"
    assert_includes html, "class=\"tag tag-filter\""
    assert_equal 1, html.scan("<svg").count
    assert_not_includes html, "tag-selected"
    assert_not_includes html, "view-transition-name"
  end

  test "filter_link renders a selected removable filter link with view transition name for context" do
    html = filter_link(path: "/job_leads", value: "applied", icon_name: "briefcase", selected: true, label: "Applied", tag_class: "status-tag", context: "lead-status")

    assert_includes html, "style=\"view-transition-name: lead-status-applied\""
    assert_includes html, "class=\"tag tag-filter status-tag tag-selected\""
    assert_includes html, "<span>Applied</span>"
    assert_equal 2, html.scan("<svg").count
  end

  test "filter_link does not render remove icon for selected all filter" do
    html = filter_link(path: "/job_leads", value: "all", icon_name: "filter", selected: true)

    assert_includes html, "class=\"tag tag-filter tag-selected\""
    assert_equal 1, html.scan("<svg").count
  end

  test "human converts values to human readable text" do
    assert_equal "", human(nil)
    assert_equal "", human("")
    assert_equal "Job lead", human("JobLead")
    assert_equal "Job lead", human(:job_lead)
  end

  test "back_path returns request referer when present" do
    request.env["HTTP_REFERER"] = "https://example.com/from"

    assert_equal "https://example.com/from", back_path
  end

  test "back_path returns default fallback without referer" do
    request.env.delete("HTTP_REFERER")

    assert_equal "/", back_path
  end

  test "back_path returns custom fallback without referer" do
    request.env.delete("HTTP_REFERER")

    assert_equal "/dashboard", back_path(fallback: "/dashboard")
  end
end
