require 'test_helper'

class TagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user

    @tag = tags(:remote)
  end

  test 'should get index' do
    get tags_url
    assert_response :success
  end

  test 'should get edit' do
    get edit_tag_url(@tag)
    assert_response :success
  end

  test 'should update tag' do
    patch tag_url(@tag), params: { tag: { name: 'updated-remote' } }
    assert_redirected_to tags_url

    @tag.reload
    assert_equal 'updated-remote', @tag.name
  end

  test 'should not update tag with invalid name' do
    patch tag_url(@tag), params: { tag: { name: '' } }
    assert_response :unprocessable_entity
  end

  test 'should destroy tag' do
    # Create a fresh tag for this test to avoid any fixture issues
    tag_to_delete = Tag.create!(user: @user, name: 'test-tag-to-delete')
    tag_id = tag_to_delete.id

    assert Tag.exists?(tag_id), 'Tag should exist before deletion'
    assert_equal @user.id, tag_to_delete.user_id, 'Tag should belong to current user'

    assert_difference('Tag.count', -1) do
      delete tag_url(tag_to_delete)
    end

    assert_redirected_to tags_url
    assert_not Tag.exists?(tag_id)
  end

  test 'destroying a tag should remove it from all job leads' do
    job_lead_one = job_leads(:one)
    job_lead_two = job_leads(:two)

    assert_includes job_lead_one.tags, @tag
    assert_includes job_lead_two.tags, @tag

    initial_taggings_count = @tag.taggings.count
    assert initial_taggings_count > 0

    delete tag_url(@tag)

    assert_not Tag.exists?(@tag.id)
  end

  test 'should not allow user to access another users tag' do
    other_user = users(:two)
    other_tag = Tag.create!(user: other_user, name: 'other-tag')

    get edit_tag_url(other_tag)
    assert_response :not_found
  end
end
