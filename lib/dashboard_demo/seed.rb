module DashboardDemo
  # Creates the demo user and their job leads, interviews, notes, and tags from
  # data.yml. Expects to run inside a transaction that will be rolled back.
  class Seed
    def initialize(data, now:)
      @data = data
      @times = RelativeTime.new(now)
    end

    def call
      user = create_user
      @data.fetch("job_leads").each_with_index { |attributes, index| create_job_lead(user, attributes, index) }
      user
    end

    private

    def create_user
      user_data = @data.fetch("user")
      email_address = user_data.fetch("email")

      # If a real account already uses the demo's email, move it aside. This is
      # rolled back with everything else.
      User.where(email_address:).update_all(email_address: "displaced-#{SecureRandom.hex(8)}@example.invalid")

      User.create!(
        name: user_data.fetch("name"),
        email_address:,
        password: SecureRandom.base58(32),
        settings: user_data.fetch("settings", {})
      )
    end

    def create_job_lead(user, attributes, index)
      created_at = time(attributes, "created")
      milestones = %w[applied offer accepted rejected archived].index_with { time(attributes, it) }

      job_lead = user.job_leads.create!(
        title: attributes.fetch("title"),
        company: attributes.fetch("company"),
        source: attributes["source"],
        location: attributes["location"],
        application_url: "https://jobs.example.com/#{attributes.fetch('company').parameterize}/#{index + 1}",
        offer_amount: attributes["offer_amount"],
        applied_at: milestones["applied"],
        offer_at: milestones["offer"],
        accepted_at: milestones["accepted"],
        rejected_at: milestones["rejected"],
        archived_at: milestones["archived"],
        created_at:,
        updated_at: [ created_at, *milestones.values.compact ].max
      )

      Array(attributes["tags"]).each do |name|
        job_lead.taggings.create!(tag: user.tags.find_or_create_by!(name:))
      end

      create_notes(user, job_lead, attributes)
      Array(attributes["interviews"]).each { create_interview(user, job_lead, it) }
    end

    def create_interview(user, job_lead, attributes)
      scheduled_at = time(attributes, "scheduled")
      # Interviews are logged about a week ahead, but never before the lead or after "now".
      scheduled_on_at = [ [ scheduled_at - 7.days, job_lead.created_at ].max, Time.current ].min

      interview = job_lead.interviews.create!(
        interviewer: attributes.fetch("interviewer"),
        location: attributes["location"],
        rating: attributes["rating"],
        scheduled_at:,
        created_at: scheduled_on_at,
        updated_at: scheduled_on_at
      )

      create_notes(user, interview, attributes)
    end

    def create_notes(user, notable, attributes)
      Array(attributes["notes"]).each do |note|
        created_at = time(note, "created")
        user.notes.create!(notable:, content: note.fetch("content"), created_at:, updated_at: created_at)
      end
    end

    def time(attributes, key) = @times.parse(attributes[key])
  end
end
