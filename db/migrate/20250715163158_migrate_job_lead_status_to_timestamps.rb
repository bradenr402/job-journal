class MigrateJobLeadStatusToTimestamps < ActiveRecord::Migration[8.0]
  def up
    add_column :job_leads, :applied_at, :datetime unless column_exists?(:job_leads, :applied_at)
    add_index :job_leads, :applied_at unless index_exists?(:job_leads, :applied_at)

    add_column :job_leads, :offer_at, :datetime unless column_exists?(:job_leads, :offer_at)
    add_index :job_leads, :offer_at unless index_exists?(:job_leads, :offer_at)

    add_column :job_leads, :rejected_at, :datetime unless column_exists?(:job_leads, :rejected_at)
    add_index :job_leads, :rejected_at unless index_exists?(:job_leads, :rejected_at)

    add_column :job_leads, :accepted_at, :datetime unless column_exists?(:job_leads, :accepted_at)
    add_index :job_leads, :accepted_at unless index_exists?(:job_leads, :accepted_at)

    JobLead.find_each do |job_lead|
      attrs = {}

      if job_lead.status.in?(1..6)
        attrs[:applied_at] = job_lead.updated_at unless job_lead.applied_at?
      end

      # skip `phone_screen` status (2)
      # all job leads with `phone_screen` status are mapped to `applied`

      if job_lead.status.in?(3..6) && job_lead.interviews.none?
        job_lead.interviews.create!(
          scheduled_at: job_lead.updated_at,
          interviewer: 'Imported'
        )
      end

      if job_lead.status.in? [ 4, 6 ]
        attrs[:offer_at] = job_lead.updated_at unless job_lead.offer_at?
      end

      if job_lead.status == 5
        attrs[:rejected_at] = job_lead.updated_at unless job_lead.rejected_at?
      end

      if job_lead.status == 6
        attrs[:accepted_at] = job_lead.updated_at unless job_lead.accepted_at?
      end

      job_lead.update_columns(attrs) if attrs.any?
    end

    remove_column :job_leads, :status
  end

  def down
    add_column :job_leads, :status, :integer, default: 0, null: false

    JobLead.find_each do |job_lead|
      status =
        case
        when job_lead.accepted_at then 6
        when job_lead.rejected_at then 5
        when job_lead.offer_at then 4
        when job_lead.interviews.exists? then 3
        when job_lead.applied_at then 1
        else 0
        end

      job_lead.update_column(:status, status)
    end

    remove_index :job_leads, :applied_at if index_exists?(:job_leads, :applied_at)
    remove_column :job_leads, :applied_at if column_exists?(:job_leads, :applied_at)

    remove_index :job_leads, :offer_at if index_exists?(:job_leads, :offer_at)
    remove_column :job_leads, :offer_at if column_exists?(:job_leads, :offer_at)

    remove_index :job_leads, :rejected_at if index_exists?(:job_leads, :rejected_at)
    remove_column :job_leads, :rejected_at if column_exists?(:job_leads, :rejected_at)

    remove_index :job_leads, :accepted_at if index_exists?(:job_leads, :accepted_at)
    remove_column :job_leads, :accepted_at if column_exists?(:job_leads, :accepted_at)
  end
end
