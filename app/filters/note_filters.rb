class NoteFilters < ApplicationFilters
  NOTABLE_TYPES = %w[ JobLead Interview ].freeze

  # Filters by the state of the note's job lead.
  # If the notable is an interview, it will filter by the state of the interview's job lead.
  filter :state, allowed: JobLeadFilters::STATES, default: "all", setting: %i[filters notes] do |scope, state|
    job_leads = state == "archived" ? user.job_leads.archived : user.job_leads.active

    scope.where(notable_type: "JobLead", notable_id: job_leads.pluck(:id))
      .or(scope.where(notable_type: "Interview", notable_id: Interview.where(job_lead: job_leads).pluck(:id)))
  end

  filter :notable_type, allowed: NOTABLE_TYPES do |scope, notable_type|
    scope.where(notable_type:)
  end

  with_options direction: :desc do
    sort_option :created, column: :created_at
    sort_option :updated, column: :updated_at
  end
end
