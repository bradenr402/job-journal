require 'test_helper'

class UserTest < ActiveSupport::TestCase
  EMAIL = 'test@example.com'
  PASSWORD = 'Valid#123'

  def setup
    @user = users(:one)
  end

  test 'should be valid with valid attributes' do
    assert @user.valid?
  end

  test 'should require email' do
    @user.email_address = ''
    assert_not @user.valid?
    assert_includes @user.errors[:email_address], "can't be blank"
  end

  test 'should enforce unique email' do
    @user.save!
    duplicate_user = @user.dup
    assert_not duplicate_user.valid?
    assert_includes duplicate_user.errors[:email_address], 'has already been taken'
  end

  test 'email should be normalized' do
    mixed_case_email = '  Foo@GmAiL.CoM   '
    @user.email_address = mixed_case_email
    @user.save!
    assert_equal mixed_case_email.strip.downcase, @user.reload.email_address
  end
end
