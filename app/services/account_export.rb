require "csv"

# Builds a portable copy of everything a user has stored in JobJournal.
class AccountExport
  DATASETS = %w[job_leads interviews notes].freeze

  JOB_LEAD_COLUMNS = %w[id title company status application_url source contact location salary offer_amount tags created_at applied_at offer_at accepted_at rejected_at archived_at updated_at].freeze
  INTERVIEW_COLUMNS = %w[id job_lead_id job_lead_title company interviewer scheduled_at location call_url rating created_at updated_at].freeze
  NOTE_COLUMNS = %w[id attached_to_type attached_to_id content created_at updated_at].freeze

  def initialize(user)
    @user = user
  end

  def to_json(*)
    JSON.pretty_generate(
      exported_at: Time.current.iso8601,
      account: { name: user.name, email_address: user.email_address, created_at: user.created_at.iso8601 },
      settings: user.settings,
      tags: user.tags.order(:name).pluck(:name),
      job_leads: job_leads.map { job_lead_json(it) }
    )
  end

  def to_csv(dataset)
    case dataset.to_s
    when "job_leads" then build_csv(JOB_LEAD_COLUMNS, job_leads.map { job_lead_hash(it) })
    when "interviews" then build_csv(INTERVIEW_COLUMNS, interviews.map { interview_hash(it) })
    when "notes" then build_csv(NOTE_COLUMNS, notes.map { note_hash(it) })
    else raise ArgumentError, "Unknown dataset: #{dataset}"
    end
  end

  private

  attr_reader :user

  def job_leads = user.job_leads.includes(:tags, :notes, interviews: :notes).order(:created_at)
  def interviews = user.interviews.includes(:job_lead).order(:scheduled_at)
  def notes = user.notes.order(:created_at)

  # Notes are nested under the record they belong to, like interviews under job leads.
  def job_lead_json(job_lead)
    job_lead_hash(job_lead).merge(
      notes: nested_notes(job_lead),
      interviews: job_lead.interviews.sort_by(&:scheduled_at).map { interview_hash(it).merge(notes: nested_notes(it)) }
    )
  end

  def nested_notes(notable) = notable.notes.sort_by(&:created_at).map { note_hash(it).except(:attached_to_type, :attached_to_id) }

  def job_lead_hash(job_lead)
    {
      id: job_lead.id,
      title: job_lead.title,
      company: job_lead.company,
      status: job_lead.status,
      application_url: job_lead.application_url,
      source: job_lead.source,
      contact: job_lead.contact,
      location: job_lead.location,
      salary: job_lead.salary,
      offer_amount: job_lead.offer_amount&.to_s("F"),
      tags: job_lead.tags.map(&:name).sort,
      created_at: timestamp(job_lead.created_at),
      applied_at: timestamp(job_lead.applied_at),
      offer_at: timestamp(job_lead.offer_at),
      accepted_at: timestamp(job_lead.accepted_at),
      rejected_at: timestamp(job_lead.rejected_at),
      archived_at: timestamp(job_lead.archived_at),
      updated_at: timestamp(job_lead.updated_at)
    }
  end

  def interview_hash(interview)
    {
      id: interview.id,
      job_lead_id: interview.job_lead_id,
      job_lead_title: interview.job_lead.title,
      company: interview.job_lead.company,
      interviewer: interview.interviewer,
      scheduled_at: timestamp(interview.scheduled_at),
      location: interview.location,
      call_url: interview.call_url,
      rating: interview.rating,
      created_at: timestamp(interview.created_at),
      updated_at: timestamp(interview.updated_at)
    }
  end

  def note_hash(note)
    {
      id: note.id,
      attached_to_type: note.notable_type.underscore,
      attached_to_id: note.notable_id,
      content: note.content,
      created_at: timestamp(note.created_at),
      updated_at: timestamp(note.updated_at)
    }
  end

  def build_csv(columns, rows)
    CSV.generate do |csv|
      csv << columns
      rows.each do |row|
        csv << columns.map { |column| escape_formula(Array(row[column.to_sym]).join(", ").presence) }
      end
    end
  end

  def timestamp(time) = time&.iso8601

  # Spreadsheet apps run cells starting with these characters as formulas.
  def escape_formula(value) = value&.match?(/\A\s*[=+\-@|\t\r]/) ? "'#{value}" : value
end
