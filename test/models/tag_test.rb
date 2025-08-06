require 'test_helper'

class TagTest < ActiveSupport::TestCase
  def setup
    @tag = tags(:remote)
  end

  test 'should be valid with valid attributes' do
    assert @tag.valid?
  end

  test 'should require name' do
    @tag.name = ''
    assert_not @tag.valid?
    assert_includes @tag.errors[:name], "can't be blank"
  end

  test 'should require user' do
    @tag.user = nil
    assert_not @tag.valid?
    assert_includes @tag.errors[:user], 'must exist'
  end

  test 'should validate uniqueness of name' do
    @user = users(:one)

    new_tag = @user.tags.build(name: @tag.name)
    assert_not new_tag.valid?
    assert_includes new_tag.errors[:name], 'has already been taken'
  end
end
