require 'test_helper'

class TaggingTest < ActiveSupport::TestCase
  def setup
    @tagging = taggings(:one_remote)
  end

  test 'should be valid with valid attributes' do
    assert @tagging.valid?
  end

  test 'should require tag' do
    @tagging.tag = nil
    assert_not @tagging.valid?
    assert_includes @tagging.errors[:tag], 'must exist'
  end

  test 'should require job lead' do
    @tagging.job_lead = nil
    assert_not @tagging.valid?
    assert_includes @tagging.errors[:job_lead], 'must exist'
  end
end
