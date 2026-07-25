class JobLeadFilters < ApplicationFilters
  STATES = %w[ all active archived ].freeze

  filter :state, param: :job_lead_state, allowed: STATES, default: "all", setting: %i[filters job_leads] do |scope, state|
    state == "archived" ? scope.archived : scope.active
  end

  filter :status, allowed: JobLead::STATUSES do |scope, status|
    scope.with_status(status)
  end

  filter :source do |scope, source|
    scope.where("LOWER(source) = ?", source.downcase)
  end

  filter :tag_names, param: :tags, parse: ->(raw) { raw.to_s.split(",").map(&:strip).compact_blank.uniq } do |scope, tag_names|
    scope.with_tags(tag_names)
  end

  sort_option :title, text: true
  sort_option :company, text: true

  with_options direction: :desc do
    sort_option :created,  column: :created_at
    sort_option :updated,  column: :updated_at
    sort_option :applied,  column: :applied_at
    sort_option :offer,    column: :offer_at
    sort_option :rejected, column: :rejected_at
    sort_option :accepted, column: :accepted_at
    sort_option :archived, column: :archived_at
  end
end
