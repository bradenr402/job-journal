class AddNullConstraintToInterviewsInterviewer < ActiveRecord::Migration[8.0]
  def change
    Interview.where(interviewer: nil).update_all(interviewer: 'unknown')
    change_column_null :interviews, :interviewer, false
  end
end
