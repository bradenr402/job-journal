require 'test_helper'

class InterviewTest < ActiveSupport::TestCase
  def setup
    @interview = interviews(:one)
  end

  test 'should be valid with valid attributes' do
    assert @interview.valid?
  end

  test 'should require interviewer' do
    @interview.interviewer = ''
    assert_not @interview.valid?
    assert_includes @interview.errors[:interviewer], "can't be blank"
  end

  test 'should require scheduled_at' do
    @interview.scheduled_at = ''
    assert_not @interview.valid?
    assert_includes @interview.errors[:scheduled_at], "can't be blank"
  end

  test 'should require a valid call_url' do
    @interview.call_url = 'not_a_valid_url'
    assert_not @interview.valid?
    assert_includes @interview.errors[:call_url], 'is invalid'
  end

  test 'should enforce numericality of rating' do
    @interview.rating = -1

    assert_not @interview.valid?
    assert_includes @interview.errors[:rating], 'must be greater than or equal to 1'

    @interview.rating = 6

    assert_not @interview.valid?
    assert_includes @interview.errors[:rating], 'must be less than or equal to 5'
  end
end
