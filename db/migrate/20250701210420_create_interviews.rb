class CreateInterviews < ActiveRecord::Migration[8.0]
  def change
    create_table :interviews do |t|
      t.references :job_lead, null: false, foreign_key: true

      t.string :interviewer
      t.datetime :scheduled_at, null: false

      t.string :location
      t.integer :rating
      t.string :call_url

      t.timestamps
    end

    add_check_constraint :interviews, '(rating BETWEEN 1 AND 5) OR rating IS NULL', name: 'rating_between_1_and_5'
  end
end
