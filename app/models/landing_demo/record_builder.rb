class LandingDemo
  class RecordBuilder
    def lead(attributes)
      status = attributes.fetch(:status)

      JobLead.new(**attributes.except(:status, :status_at, :tags, :notes_count)).tap do |lead|
        lead.define_singleton_method(:status) { status }
        lead.define_singleton_method(:latest_status_at) { attributes[:status_at] }

        preload_association(lead, :tags, tags_for(lead, attributes.fetch(:tags, [])))
        preload_association(lead, :notes, notes_for(lead, attributes.fetch(:notes_count, 0), 5000))
      end
    end

    def interview(attributes)
      Interview.new(**attributes.except(:notes_count)).tap do |interview|
        preload_association(interview, :notes, notes_for(interview, attributes.fetch(:notes_count, 0), 6000))
      end
    end

    private

    def tags_for(lead, tags)
      tags.map.with_index { |name, index| Tag.new(id: 4000 + lead.id * 10 + index, name:) }
    end

    def notes_for(record, count, id_base)
      count.times.map { |index| Note.new(id: id_base + record.id * 10 + index) }
    end

    def preload_association(record, name, records)
      record.association(name).tap do |association|
        association.target = records
        association.loaded!
      end
    end
  end
end
