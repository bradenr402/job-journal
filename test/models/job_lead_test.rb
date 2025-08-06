require 'test_helper'

class JobLeadTest < ActiveSupport::TestCase
  def setup
    @lead = job_leads(:one)
  end

  test 'should be valid with valid attributes' do
    assert @lead.valid?
  end

  test 'should require title' do
    @lead.title = ''
    assert_not @lead.valid?
    assert_includes @lead.errors[:title], "can't be blank"
  end

  test 'should require company' do
    @lead.company = ''
    assert_not @lead.valid?
    assert_includes @lead.errors[:company], "can't be blank"
  end

  test 'should require application_url' do
    @lead.application_url = ''
    assert_not @lead.valid?
    assert_includes @lead.errors[:application_url], "can't be blank"
  end

  test 'should require a valid application_url' do
    @lead.application_url = 'not_a_valid_url'
    assert_not @lead.valid?
    assert_includes @lead.errors[:application_url], 'is invalid'
  end

  test 'should require a unique application_url' do
    @lead.application_url = 'https://example.com/apply'
    @lead.save!

    duplicate = @lead.dup
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:application_url], 'has already been taken'
  end

  test 'should enforce numericality of offer_amount' do
    lead = JobLead.new(
      user: @lead.user,
      title: 'Example',
      company: 'Example Co.',
      application_url: 'https://example.com/unique',
      offer_amount: -100
    )

    assert_not lead.valid?
    assert_includes lead.errors[:offer_amount], 'must be greater than or equal to 0'
  end

  test 'should validate temporal logic on accepted_at' do
    @lead.accepted_at = 1.day.from_now
    assert_not @lead.valid?
    assert @lead.errors[:accepted_at].any? { |msg| msg.include? 'must be less than or equal to' }
  end

  test 'should infer status correctly' do
    assert_equal 'rejected', @lead.status
  end

  test 'should enforce single terminal status' do
    @lead.accepted_at = Time.current
    assert_not @lead.valid?
    assert_includes @lead.errors[:base], 'cannot be both rejected and accepted'
  end

  test 'should require offer amount if offer_at is present' do
    @lead.offer_at = Time.current
    @lead.offer_amount = nil
    assert_not @lead.valid?
    assert_includes @lead.errors[:base], 'cannot advance to Offer without specifying an offer amount'
  end

  test 'should assign tags after save' do
    @lead.tag_list = 'Fake, Tags, Right, Here'
    assert_difference -> { @lead.user.tags.count }, 4 do
      @lead.save!
    end
    assert_equal %w[fake here right tags], @lead.tags.pluck(:name).sort
  end
end
