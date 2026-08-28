require "application_system_test_case"

class TagsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @tag = tags(:remote)

    visit new_session_url
    fill_in "Email Address", with: @user.email_address
    fill_in "Password", with: "password"
    click_on "Sign In"
  end

  test "warns and asks for confirmation before merging a tag into an existing one" do
    visit edit_tag_url(@tag)

    fill_in "Name", with: "Rails"
    assert_text "You already have a tag named “rails”. Saving will merge the two tags: " \
                "every job lead tagged “remote” will be tagged “rails” instead, and “remote” will be deleted."

    message = dismiss_confirm { click_on "Save Changes" }
    assert_equal "Merge the 'remote' tag into 'rails'?\n\n" \
                 "Every job lead tagged 'remote' will be tagged 'rails' instead, " \
                 "and the 'remote' tag will be deleted. This can't be undone.", message

    assert_current_path edit_tag_path(@tag)
    assert Tag.exists?(@tag.id), "dismissing the confirmation should leave the tag alone"

    accept_confirm { click_on "Save Changes" }

    assert_text "Tag 'remote' was merged into 'rails'."
    assert_not Tag.exists?(@tag.id)
  end

  test "renaming a tag to an unused name does not ask for confirmation" do
    visit edit_tag_url(@tag)

    fill_in "Name", with: "work from home"
    assert_no_text "You already have a tag named"

    click_on "Save Changes"

    assert_text "Tag was successfully updated."
    assert_equal "work from home", @tag.reload.name
  end

  test "warns when the new name differs only by case or whitespace" do
    visit edit_tag_url(@tag)

    fill_in "Name", with: "  RAILS  "
    assert_text "You already have a tag named"

    accept_confirm { click_on "Save Changes" }

    assert_text "Tag 'remote' was merged into 'rails'."
  end
end
