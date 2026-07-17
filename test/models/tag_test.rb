require "test_helper"

class TagTest < ActiveSupport::TestCase
  setup do
    @tag = tags(:remote)
  end

  teardown do
    Tag.destroy_all
  end

  test "should be valid with valid attributes" do
    assert @tag.valid?
  end

  test "should require name" do
    @tag.name = ""

    assert_not @tag.valid?
    assert_includes @tag.errors[:name], "can't be blank"
  end

  test "should require user" do
    @tag.user = nil

    assert_not @tag.valid?
    assert_includes @tag.errors[:user], "must exist"
  end

  test "name should be normalized" do
    tag = users(:one).tags.create!(name: "MiXeD")

    assert_equal "mixed", tag.reload.name
  end

  test "should validate uniqueness of name for the same user case insensitively" do
    new_tag = users(:one).tags.build(name: @tag.name.upcase)

    assert_not new_tag.valid?
    assert_includes new_tag.errors[:name], "has already been taken"
  end

  test "should allow the same name for different users" do
    new_tag = users(:two).tags.build(name: @tag.name.upcase)

    assert new_tag.valid?
  end

  test "unused should return tags without taggings" do
    unused_tag = users(:one).tags.create!(name: "unused test tag")
    used_tag = users(:one).tags.create!(name: "used test tag")
    used_tag.taggings.create!(job_lead: job_leads(:one))

    assert_includes Tag.unused, unused_tag
    assert_not_includes Tag.unused, used_tag
  end

  test "top_by_usage should order tags by tagging count descending" do
    top_tag = users(:one).tags.create!(name: "top usage tag")
    lower_tag = users(:one).tags.create!(name: "lower usage tag")
    leads = 3.times.map { |i| create_job_lead(application_url: "https://example.com/top-tag-#{i}") }

    leads.each { |lead| top_tag.taggings.create!(job_lead: lead) }
    lower_tag.taggings.create!(job_lead: leads.first)

    assert_equal top_tag, Tag.top_by_usage.first
  end

  test "cleanup_unused_for_user should destroy only unused tags for the user" do
    user_unused_tag = users(:one).tags.create!(name: "cleanup unused")
    user_used_tag = users(:one).tags.create!(name: "cleanup used")
    other_user_unused_tag = users(:two).tags.create!(name: "other cleanup unused")

    user_used_tag.taggings.create!(job_lead: job_leads(:one))

    assert_difference -> { users(:one).tags.count }, -1 do
      Tag.cleanup_unused_for_user(users(:one))
    end

    assert_not Tag.exists?(user_unused_tag.id)
    assert Tag.exists?(user_used_tag.id)
    assert Tag.exists?(other_user_unused_tag.id)
  end

  private

  def create_job_lead(attributes = {})
    users(:one).job_leads.create!({
      title: "Example",
      company: "Example Co.",
      application_url: "https://example.com/jobs/tag-test-#{SecureRandom.hex(8)}"
    }.merge(attributes))
  end
end
