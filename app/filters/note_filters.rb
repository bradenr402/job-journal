class NoteFilters < ApplicationFilters
  NOTABLE_TYPES = %w[ JobLead Interview ].freeze

  filter :job_lead_state, allowed: JobLeadFilters::STATES, default: "all", setting: %i[filters notes] do |scope, state|
    archived_lead_notes = { notable_type: "JobLead", notable_id: user.job_leads.archived.select(:id) }

    state == "archived" ? scope.where(archived_lead_notes) : scope.where.not(archived_lead_notes)
  end

  filter :notable_type, allowed: NOTABLE_TYPES do |scope, notable_type|
    scope.where(notable_type:)
  end

  sort_option :created, column: :created_at, direction: :desc
  sort_option :updated, column: :updated_at, direction: :desc
end
