require 'test_helper'

class NoteTest < ActiveSupport::TestCase
  def setup
    @note = notes(:one)
  end

  test 'should be valid with valid attributes' do
    assert @note.valid?
  end

  test 'should require content' do
    @note.content = ''
    assert_not @note.valid?
    assert_includes @note.errors[:content], "can't be blank"
  end

  test 'title should return correct note title' do
    job_lead_note = notes(:one)
    job_lead = job_lead_note.notable

    assert_equal job_lead_note.title, "#{job_lead.title} @ #{job_lead.company}"

    interview_note = notes(:two)
    interview = interview_note.notable
    job_lead = interview.job_lead

    assert_equal interview_note.title, "Interview with #{interview.interviewer} - #{job_lead.title} @ #{job_lead.company}"
  end
end
