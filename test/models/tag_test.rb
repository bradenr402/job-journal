require "test_helper"
require "minitest/mock"

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

  test "name should be squished" do
    tag = users(:one).tags.create!(name: "  Remote   First  Role ")

    assert_equal "remote first role", tag.reload.name
  end

  test "names differing only by surrounding or repeated whitespace are duplicates" do
    users(:one).tags.create!(name: "remote first")
    duplicate = users(:one).tags.build(name: "  Remote   First  ")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "rename_to! updates and normalizes the name" do
    result = @tag.rename_to!("MiXeD Remote")

    assert_equal @tag, result
    assert_equal "mixed remote", @tag.reload.name
  end

  test "rename_to! to a differently-cased version of its own name does not merge or delete" do
    result = nil

    assert_no_difference [ "Tag.count", "Tagging.count" ] do
      result = @tag.rename_to!("REMOTE")
    end

    assert_equal @tag, result
    assert Tag.exists?(@tag.id)
    assert_equal "remote", @tag.reload.name
  end

  test "rename_to! merges into an existing tag for the same user" do
    old_tag = users(:one).tags.create!(name: "old merge")
    existing_tag = users(:one).tags.create!(name: "existing merge")
    job_lead = create_job_lead(application_url: "https://example.com/merge-basic")
    old_tag.taggings.create!(job_lead: job_lead)

    result = old_tag.rename_to!("Existing Merge")

    assert_equal existing_tag, result
    assert_not Tag.exists?(old_tag.id)
    assert Tag.exists?(existing_tag.id)
    assert_equal [ existing_tag ], job_lead.reload.tags.where(name: "existing merge").to_a
  end

  test "rename_to! removes duplicate taggings when merging a job lead with both tags" do
    old_tag = users(:one).tags.create!(name: "old duplicate")
    existing_tag = users(:one).tags.create!(name: "existing duplicate")
    job_lead = create_job_lead(application_url: "https://example.com/merge-duplicate")
    old_tag.taggings.create!(job_lead: job_lead)
    existing_tag.taggings.create!(job_lead: job_lead)

    assert_difference -> { Tagging.count }, -1 do
      old_tag.rename_to!("existing duplicate")
    end

    assert_equal 1, job_lead.taggings.where(tag: existing_tag).count
    assert_not Tagging.exists?(tag: old_tag)
  end

  test "rename_to! moves taggings across multiple job leads when merging" do
    old_tag = users(:one).tags.create!(name: "old multi")
    existing_tag = users(:one).tags.create!(name: "existing multi")
    first_lead = create_job_lead(application_url: "https://example.com/merge-multi-1")
    second_lead = create_job_lead(application_url: "https://example.com/merge-multi-2")
    old_tag.taggings.create!(job_lead: first_lead)
    old_tag.taggings.create!(job_lead: second_lead)

    old_tag.rename_to!("existing multi")

    assert_equal [ existing_tag ], first_lead.reload.tags.where(name: "existing multi").to_a
    assert_equal [ existing_tag ], second_lead.reload.tags.where(name: "existing multi").to_a
    assert_equal 2, existing_tag.taggings.where(job_lead: [ first_lead, second_lead ]).count
  end

  test "rename_to! does not merge with another user's same-named tag" do
    other_user_tag = users(:two).tags.create!(name: "other user tag")

    result = @tag.rename_to!("Other User Tag")

    assert_equal @tag, result
    assert_equal "other user tag", @tag.reload.name
    assert Tag.exists?(other_user_tag.id)
    assert_equal users(:two), other_user_tag.reload.user
  end

  test "rename_to! rolls back merge changes when destroying the old tag fails" do
    old_tag = users(:one).tags.create!(name: "old rollback")
    existing_tag = users(:one).tags.create!(name: "existing rollback")
    duplicate_lead = create_job_lead(application_url: "https://example.com/merge-rollback-duplicate")
    moved_lead = create_job_lead(application_url: "https://example.com/merge-rollback-moved")
    old_tag.taggings.create!(job_lead: duplicate_lead)
    existing_tag.taggings.create!(job_lead: duplicate_lead)
    old_tag.taggings.create!(job_lead: moved_lead)

    assert_raises RuntimeError do
      old_tag.stub(:delete, -> { raise "boom" }) do
        old_tag.rename_to!("existing rollback")
      end
    end

    assert Tag.exists?(old_tag.id)
    assert_equal 2, old_tag.taggings.count
    assert_equal 1, existing_tag.taggings.count
    assert_equal [ old_tag ], moved_lead.reload.tags.where(name: "old rollback").to_a
  end

  test "rename_to! with invalid name raises and changes nothing" do
    assert_raises ActiveRecord::RecordInvalid do
      @tag.rename_to!("")
    end

    assert_equal "remote", @tag.reload.name
  end

  test "rename_to returns false with errors when the name is invalid" do
    assert_equal false, @tag.rename_to("")
    assert_includes @tag.errors[:name], "can't be blank"
    assert_equal "remote", @tag.reload.name
  end

  test "rename_to returns the surviving tag when successful" do
    existing_tag = tags(:rails)

    assert_equal existing_tag, @tag.rename_to("Rails")
    assert_not Tag.exists?(@tag.id)
    assert Tag.exists?(existing_tag.id)
  end

  test "rename_to returns false with errors when losing a unique index race" do
    @tag.stub(:update!, proc { raise ActiveRecord::RecordNotUnique.new("race") }) do
      assert_equal false, @tag.rename_to("race target")
    end

    assert_includes @tag.errors[:name], "has already been taken"
    assert_equal "remote", @tag.reload.name
  end

  test "rename_to! merges names that differ only by whitespace" do
    old_tag = users(:one).tags.create!(name: "old whitespace")
    existing_tag = users(:one).tags.create!(name: "existing whitespace")
    job_lead = create_job_lead(application_url: "https://example.com/merge-whitespace")
    old_tag.taggings.create!(job_lead: job_lead)

    result = old_tag.rename_to!("  Existing   Whitespace  ")

    assert_equal existing_tag, result
    assert_not Tag.exists?(old_tag.id)
    assert_equal [ existing_tag ], job_lead.reload.tags.where(name: "existing whitespace").to_a
  end

  test "rename_to! merges a tag that has no taggings" do
    old_tag = users(:one).tags.create!(name: "old empty")
    existing_tag = users(:one).tags.create!(name: "existing empty")

    assert_no_difference -> { Tagging.count } do
      assert_equal existing_tag, old_tag.rename_to!("existing empty")
    end

    assert_not Tag.exists?(old_tag.id)
    assert Tag.exists?(existing_tag.id)
  end

  test "rename_to! touches the job leads whose taggings were moved or removed" do
    old_tag = users(:one).tags.create!(name: "old touch")
    existing_tag = users(:one).tags.create!(name: "existing touch")
    moved_lead = create_job_lead(application_url: "https://example.com/merge-touch-moved")
    duplicate_lead = create_job_lead(application_url: "https://example.com/merge-touch-duplicate")
    untouched_lead = create_job_lead(application_url: "https://example.com/merge-touch-untouched")
    old_tag.taggings.create!(job_lead: moved_lead)
    old_tag.taggings.create!(job_lead: duplicate_lead)
    existing_tag.taggings.create!(job_lead: duplicate_lead)

    [ moved_lead, duplicate_lead, untouched_lead ].each do |lead|
      lead.update_columns(updated_at: 1.week.ago)
    end
    stale_timestamp = untouched_lead.reload.updated_at

    freeze_time do
      old_tag.rename_to!("existing touch")

      assert_equal Time.current, moved_lead.reload.updated_at
      assert_equal Time.current, duplicate_lead.reload.updated_at
    end

    assert_equal stale_timestamp, untouched_lead.reload.updated_at
  end

  test "rename_to! does not touch job leads when the name simply changes" do
    job_lead = job_leads(:one)
    job_lead.update_columns(updated_at: 1.week.ago)
    stale_timestamp = job_lead.reload.updated_at

    @tag.rename_to!("renamed remote")

    assert_equal stale_timestamp, job_lead.reload.updated_at
  end

  test "rename_to returns false with errors when the merge loses a unique index race" do
    old_tag = users(:one).tags.create!(name: "old merge race")
    users(:one).tags.create!(name: "existing merge race")

    old_tag.stub(:duplicate_named, proc { raise ActiveRecord::RecordNotUnique.new("race") }) do
      assert_equal false, old_tag.rename_to("existing merge race")
    end

    assert_includes old_tag.errors[:name], "has already been taken"
    assert Tag.exists?(old_tag.id)
  end

  test "duplicate_named ignores unpersisted tags" do
    users(:one).tags.create!(name: "already here")
    new_tag = users(:one).tags.build(name: "brand new")

    assert_nil new_tag.duplicate_named("already here")
  end

  test "a job lead cannot be tagged with the same tag twice" do
    job_lead = create_job_lead(application_url: "https://example.com/duplicate-tagging")
    @tag.taggings.create!(job_lead: job_lead)

    assert_raises ActiveRecord::RecordNotUnique do
      Tagging.insert!({ tag_id: @tag.id, job_lead_id: job_lead.id, created_at: Time.current, updated_at: Time.current })
    end
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
end
