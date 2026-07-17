require "test_helper"

class TaggingTest < ActiveSupport::TestCase
  setup do
    @tagging = taggings(:one_remote)
  end

  teardown do
    Tagging.destroy_all
  end

  test "should be valid with valid attributes" do
    assert @tagging.valid?
  end

  test "should require tag" do
    @tagging.tag = nil

    assert_not @tagging.valid?
    assert_includes @tagging.errors[:tag], "must exist"
  end

  test "should require job lead" do
    @tagging.job_lead = nil

    assert_not @tagging.valid?
    assert_includes @tagging.errors[:job_lead], "must exist"
  end

  test "should validate uniqueness of tag for a job lead" do
    duplicate = Tagging.new(job_lead: @tagging.job_lead, tag: @tagging.tag)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:tag_id], "has already been taken"
  end

  test "should allow the same tag on different job leads" do
    tagging = Tagging.new(job_lead: create_job_lead, tag: @tagging.tag)

    assert tagging.valid?
  end

  test "destroying the last tagging should destroy the orphaned tag" do
    tag = users(:one).tags.create!(name: "orphan cleanup")
    tagging = tag.taggings.create!(job_lead: create_job_lead(application_url: "https://example.com/orphan-cleanup"))

    assert_difference -> { Tag.count }, -1 do
      tagging.destroy
    end
  end

  test "destroying a tagging should keep tags with other taggings" do
    tag = users(:one).tags.create!(name: "still used")
    first_tagging = tag.taggings.create!(job_lead: create_job_lead(application_url: "https://example.com/still-used-1"))
    tag.taggings.create!(job_lead: create_job_lead(application_url: "https://example.com/still-used-2"))

    assert_no_difference -> { Tag.count } do
      first_tagging.destroy
    end
  end

  private

  def create_job_lead(attributes = {})
    users(:one).job_leads.create!({
      title: "Example",
      company: "Example Co.",
      application_url: "https://example.com/jobs/tagging-test-#{SecureRandom.hex(8)}"
    }.merge(attributes))
  end
end
