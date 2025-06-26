class CreateJobLeads < ActiveRecord::Migration[8.0]
  def change
    create_table :job_leads do |t|
      t.references :user, null: false, foreign_key: true

      t.string :company, null: false
      t.string :title, null: false

      t.text :application_url
      t.text :source
      t.text :contact
      t.string :salary

      t.decimal :offer_amount, precision: 12, scale: 2
      t.string :location

      t.integer :status, default: 0, null: false
      t.datetime :archived_at

      t.timestamps
    end

    # Enforce that offer_amount is either NULL or >= 0
    add_check_constraint :job_leads, 'offer_amount IS NULL OR offer_amount >= 0', name: 'offer_amount_non_negative'

    add_index :job_leads, :status
    add_index :job_leads, :archived_at
  end
end
