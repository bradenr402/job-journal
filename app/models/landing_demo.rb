class LandingDemo
  attr_reader :user

  def initialize(record_builder: RecordBuilder.new)
    @record_builder = record_builder
    @user = User.new(id: 0, name: "Demo User")
  end

  def leads
    @leads ||= Data::LEADS.map { |attributes| lead(attributes) }
  end

  def interviews
    @interviews ||= Data::INTERVIEWS.map { |attributes| interview(attributes) }
  end

  def notes
    @notes ||= Data::NOTES.map { |attributes| note(attributes) }
  end

  def job_lead_stats = Data::JOB_LEAD_STATS
  def application_stats = Data::APPLICATION_STATS
  def interview_stats = Data::INTERVIEW_STATS
  def suggestions = Data::SUGGESTIONS.map { materialize(it) }
  def stale_leads = @stale_leads ||= Data::STALE_LEADS.map { |attributes| lead(attributes) }
  def sources = Data::SOURCES
  def top_tags = Data::TOP_TAGS

  private

  attr_reader :record_builder

  def lead(attributes)
    materialized = materialize(attributes)
    record_builder.lead(materialized.merge(user:))
  end

  def interview(attributes)
    materialized = materialize(attributes)
    record_builder.interview(materialized.except(:lead_index).merge(job_lead: leads.fetch(materialized.fetch(:lead_index))))
  end

  def note(attributes)
    materialized = materialize(attributes)
    Note.new(materialized.except(:notable).merge(user:, notable: notable_for(materialized.fetch(:notable))))
  end

  def notable_for((collection, index))
    public_send(collection).fetch(index)
  end

  def materialize(attributes)
    attributes.transform_values { it.respond_to?(:call) ? it.call : it }
  end
end
