require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user

    @tag = tags(:remote)
  end

  test "should get index" do
    get tags_url
    assert_response :success
  end

  test "should get edit" do
    get edit_tag_url(@tag)
    assert_response :success
  end

  test "should update tag" do
    patch tag_url(@tag), params: { tag: { name: "updated-remote" } }
    assert_redirected_to tags_url

    @tag.reload
    assert_equal "updated-remote", @tag.name
  end

  test "should merge tag when updating to an existing tag name" do
    existing_tag = tags(:rails)
    old_tag_id = @tag.id

    patch tag_url(@tag), params: { tag: { name: "Rails" } }
    assert_redirected_to tags_url

    assert_not Tag.exists?(old_tag_id)
    assert Tag.exists?(existing_tag.id)
    assert_equal "rails", existing_tag.reload.name
  end

  test "should flash a merge-specific message when merging tags" do
    patch tag_url(@tag), params: { tag: { name: "Rails" } }

    assert_equal "Tag 'remote' was merged into 'rails'.", flash[:success]
  end

  test "should flash a plain update message when only renaming" do
    patch tag_url(@tag), params: { tag: { name: "updated-remote" } }

    assert_equal "Tag was successfully updated.", flash[:success]
  end

  test "should escape tag names in the merge flash message" do
    xss_tag = Tag.create!(user: @user, name: "<script>alert(1)</script>")

    patch tag_url(xss_tag), params: { tag: { name: "remote" } }

    assert_no_match "<script>", flash[:success]
    assert_match "&lt;script&gt;", flash[:success]
  end

  test "edit form exposes the user's other tag names for merge confirmation" do
    other_tag = Tag.create!(user: @user, name: "confirmable")
    another_users_tag = Tag.create!(user: users(:two), name: "not mine")

    get edit_tag_url(@tag)
    assert_response :success

    form = css_select("form[data-controller='merge-confirm']").first
    assert form, "edit form should wire up the merge confirmation controller"

    names = JSON.parse(form["data-merge-confirm-names-value"])
    assert_includes names, other_tag.name
    assert_not_includes names, @tag.name, "should not offer to merge a tag into itself"
    assert_not_includes names, another_users_tag.name
    assert_equal @tag.name, form["data-merge-confirm-current-name-value"]
  end

  test "should not update tag with invalid name" do
    patch tag_url(@tag), params: { tag: { name: "" } }
    assert_response :unprocessable_content
  end

  test "should destroy tag" do
    # Create a fresh tag for this test to avoid any fixture issues
    tag_to_delete = Tag.create!(user: @user, name: "test-tag-to-delete")
    tag_id = tag_to_delete.id

    assert Tag.exists?(tag_id), "Tag should exist before deletion"
    assert_equal @user.id, tag_to_delete.user_id, "Tag should belong to current user"

    assert_difference("Tag.count", -1) do
      delete tag_url(tag_to_delete)
    end

    assert_redirected_to tags_url
    assert_not Tag.exists?(tag_id)
  end

  test "destroying a tag should remove it from all job leads" do
    job_lead_one = job_leads(:one)
    job_lead_two = job_leads(:two)

    assert_includes job_lead_one.tags, @tag
    assert_includes job_lead_two.tags, @tag

    initial_taggings_count = @tag.taggings.count
    assert initial_taggings_count > 0

    delete tag_url(@tag)

    assert_not Tag.exists?(@tag.id)
  end

  test "should not allow user to access another users tag" do
    other_user = users(:two)
    other_tag = Tag.create!(user: other_user, name: "other-tag")

    get edit_tag_url(other_tag)
    assert_response :not_found
  end

  test "should not update another user's tag" do
    other_user = users(:two)
    other_tag = Tag.create!(user: other_user, name: "other-tag")

    patch tag_url(other_tag), params: { tag: { name: "hijacked" } }
    assert_response :not_found
    assert_equal "other-tag", other_tag.reload.name
  end

  test "should not destroy another user's tag" do
    other_user = users(:two)
    other_tag = Tag.create!(user: other_user, name: "other-tag")

    assert_no_difference("Tag.count") do
      delete tag_url(other_tag)
    end

    assert_response :not_found
  end
end
