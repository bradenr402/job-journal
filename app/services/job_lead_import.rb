require "csv"

# Imports job leads from a user-supplied CSV. Columns are matched to job lead
# fields (guessed from the headers, adjustable by the user), every row is
# validated up front for a preview, and valid rows are saved in one transaction.
class JobLeadImport
  MAX_BYTES = 1.megabyte
  MAX_ROWS = 2_000
  PREVIEW_ROWS = 20
  DUPLICATE_STRATEGIES = %w[skip update].freeze
  OFFER_AMOUNT_MISSING = "Offer Amount is missing".freeze
  DATE_FORMATS = %w[mdy dmy].freeze
  NUMERIC_DATE = %r{\A(\d{1,2})[/.-](\d{1,2})[/.-](\d{2}|\d{4})(?:\s+(.+))?\z}

  # field => [label, header aliases]
  FIELDS = {
    "title" => [ "Job Title", %w[title jobtitle position role] ],
    "company" => [ "Company", %w[company companyname employer organization] ],
    "application_url" => [ "Application URL", %w[applicationurl url link joburl joblink postingurl postinglink applicationlink] ],
    "status" => [ "Status", %w[status stage] ],
    "location" => [ "Location", %w[location city] ],
    "salary" => [ "Posted Salary", %w[salary salaryrange pay compensation] ],
    "offer_amount" => [ "Offer Amount", %w[offeramount offer] ],
    "source" => [ "Source", %w[source foundon foundvia jobboard] ],
    "contact" => [ "Contact", %w[contact recruiter contactname] ],
    "tags" => [ "Tags", %w[tags tag labels] ],
    "created_at" => [ "Added", %w[createdat added dateadded saved datesaved] ],
    "applied_at" => [ "Applied", %w[appliedat applied dateapplied applicationdate] ],
    "offer_at" => [ "Offer Received", %w[offerat offerdate offerreceived] ],
    "accepted_at" => [ "Accepted", %w[acceptedat accepted dateaccepted] ],
    "rejected_at" => [ "Rejected", %w[rejectedat rejected daterejected] ],
    "archived_at" => [ "Archived", %w[archivedat archived] ]
  }.freeze
  FIELD_ICONS = {
    "title" => "briefcase", "company" => "company", "application_url" => "link", "status" => "status",
    "location" => "location", "salary" => "dollar", "offer_amount" => "money", "source" => "globe",
    "contact" => "contact", "tags" => "tag", "created_at" => "calendar", "applied_at" => "application",
    "offer_at" => "offer", "accepted_at" => "check-circle", "rejected_at" => "x-circle", "archived_at" => "archive"
  }.freeze
  REQUIRED_FIELDS = %w[title company application_url].freeze
  DATE_FIELDS = %w[created_at applied_at offer_at accepted_at rejected_at archived_at].freeze
  TEXT_FIELDS = %w[title company application_url location salary source contact].freeze
  STATUS_DATE_FIELDS = { "applied" => "applied_at", "offer" => "offer_at", "accepted" => "accepted_at", "rejected" => "rejected_at" }.freeze

  Row = Struct.new(:line, :job_lead, :action, :errors, :warnings, :duplicate, :fixable, :values, :changes, :skipped, :offer_choice_needed, keyword_init: true) do
    def valid? = errors.empty?
    def duplicate? = duplicate.present?
    def needs_attention? = !valid? || duplicate? || skipped
  end

  FIELD_GROUPS = {
    "Basics" => %w[title company application_url status],
    "Details" => %w[location salary offer_amount source contact tags],
    "Dates" => %w[created_at applied_at offer_at accepted_at rejected_at archived_at]
  }.freeze

  Result = Struct.new(:created, :updated, :skipped_rows, :failed_rows, :batch_tag, keyword_init: true)

  class Error < StandardError; end

  attr_reader :headers, :mapping, :on_duplicate, :date_format

  def self.field_label(field) = FIELDS.dig(field, 0)

  def initialize(user:, csv:, mapping: nil, on_duplicate: nil, overrides: {}, date_format: nil, save_errors: {})
    @user = user
    @csv = normalize_encoding(csv.to_s)
    raise Error, "The file is larger than 1 MB." if @csv.bytesize > MAX_BYTES

    table = parse
    @headers = table.first.to_a.map { it.to_s.strip }
    @data = table.drop(1).reject { |values| values.all?(&:blank?) }

    raise Error, "The file has no header row." if @headers.all?(&:blank?)
    raise Error, "The file has no rows to import." if @data.empty?
    raise Error, "The file has more than #{MAX_ROWS} rows. Split it into smaller files." if @data.size > MAX_ROWS

    @mapping = mapping.nil? ? guess_mapping : sanitize_mapping(mapping)
    @on_duplicate = on_duplicate.to_s.presence_in(DUPLICATE_STRATEGIES)
    @date_format_chosen = date_format.to_s.in?(DATE_FORMATS)
    @date_format = date_format.to_s.in?(DATE_FORMATS) ? date_format.to_s : detected_date_format
    @save_errors = save_errors.to_h.transform_keys(&:to_s)
    @overrides = overrides.to_h.transform_keys(&:to_s).transform_values { it.to_h.transform_keys(&:to_s) }
  end

  def csv_content = @csv
  def row_count = @data.size

  def samples_for(index, limit: 3) = @data.filter_map { it[index].to_s.strip.presence }.uniq.first(limit)

  # A numeric date like 03/04/2026 from the file whose meaning depends on the
  # date format, or nil when every date is unambiguous (or there are none).
  def ambiguous_date_example
    return @ambiguous_date_example if defined?(@ambiguous_date_example)

    @ambiguous_date_example = numeric_dates.find { |first, second, _| first.to_i <= 12 && second.to_i <= 12 && first != second }&.first(3)&.join("/")
  end

  def date_format_chosen? = @date_format_chosen
  def date_format_known? = ambiguous_date_example.nil? || evidence_for_date_format.present?

  def read_date(raw) = parse_time(raw)
  attr_reader :overrides

  def overrides_for(line) = @overrides.fetch(line.to_s, {})

def missing_required_fields = REQUIRED_FIELDS - mapping.keys

  # Rows the user has to look at: problems, skips they chose, and existing
  # leads where the file differs (so they must pick Skip or Update).
  def review_rows = rows.select { it.action == :fix || it.skipped || (it.duplicate? && it.changes.present?) || resolved_by_user?(it) }

  # Rows the user fixed or decided on stay on Review, so they don't vanish mid-edit.
  def resolved_by_user?(row) = overrides_for(row.line).except("skip").present? && !row.skipped

  # Rows still needing a decision (fixes or Update/Skip); drives "Continue" vs going straight to Summary.
  def needs_review? = rows.any? { it.action == :fix || it.skipped || (it.duplicate? && it.changes.present?) }

  def rows
    @rows ||= begin
      built = nil

      # Validation callbacks on existing leads can write (e.g. auto-archiving), so preview inside a rolled-back transaction.
      JobLead.transaction do
        built = build_rows
        raise ActiveRecord::Rollback
      end

      built
    end
  end

  def summary
    @summary ||= begin
      counts = rows.group_by(&:action).transform_values(&:size)
      { create: counts.fetch(:create, 0), update: counts.fetch(:update, 0), skip: counts.fetch(:skip, 0), fix: counts.fetch(:fix, 0) }
    end
  end

  def import!
    raise Error, "Choose a column for #{missing_required_fields.map { self.class.field_label(it) }.to_sentence} to continue." if missing_required_fields.any?

    batch_tag = "imported-#{Date.current.iso8601}"
    created = updated = 0

    rows = nil

    JobLead.transaction do
      rows = build_rows
      actions = rows.map(&:action)

      unresolved = actions.count(:fix)
      raise Error, "Fix or skip #{unresolved == 1 ? "the row" : "all #{unresolved} rows"} that need attention to continue." if unresolved.positive?
      raise Error, "Every row is skipped, so there’s nothing to import." if (actions & %i[create update]).empty?

      rows.each do |row|
        next unless row.action.in?(%i[create update])

        lead = row.job_lead
        lead.tag_list = (lead.pending_tag_names.to_a + [ batch_tag ]).join(",")

        if lead.save(context: validation_context_for(lead))
          row.action == :create ? created += 1 : updated += 1
        else
          row.action = :failed
          row.errors.concat(lead.errors.full_messages)
        end
      end
    end

    Result.new(created:, updated:, skipped_rows: rows.select { it.action == :skip }, failed_rows: rows.select { it.action == :failed }, batch_tag:)
  end

  private

  attr_reader :user

  # Only check step order when the import sets dates, so existing out-of-order
  # history doesn't block unrelated updates.
  def validation_context_for(lead)
    contexts = [ lead.new_record? ? :create : :update ]
    contexts << :history if lead.new_record? || DATE_FIELDS.any? { lead.will_save_change_to_attribute?(it) }
    contexts
  end

  def build_rows
    seen_urls = Set.new
    urls = @data.each_with_index.filter_map do |values, index|
      @current_line = index + 2
      value_for(values, "application_url")
    end
    @existing_leads = user.job_leads.where(application_url: urls).includes(:tags).index_by(&:application_url)
    @data.each_with_index.map { |values, index| build_row(values, line: index + 2, seen_urls:) }
  end

  def normalize_encoding(content)
    content = content.dup.force_encoding(Encoding::UTF_8)
    content = content.encode(Encoding::UTF_8, Encoding::Windows_1252) unless content.valid_encoding?
    content.delete_prefix("\uFEFF")
  end

  def parse
    CSV.parse(@csv)
  rescue CSV::MalformedCSVError => e
    raise Error, "The file couldn’t be read as CSV (#{e.message})."
  end

  def numeric_dates
    @numeric_dates ||= DATE_FIELDS.filter_map { mapping[it] }.flat_map do |index|
      @data.filter_map { NUMERIC_DATE.match(it[index].to_s.strip)&.captures }
    end
  end

  # A date like 25/03/2026 can only be day-first; 03/25/2026 only month-first.
  def evidence_for_date_format
    return "dmy" if numeric_dates.any? { |first, _, _| first.to_i > 12 }
    "mdy" if numeric_dates.any? { |_, second, _| second.to_i > 12 }
  end

  def detected_date_format = evidence_for_date_format || "mdy"

  public

  def suggested_mapping = guess_mapping

  private

  def guess_mapping
    normalized = headers.map { it.downcase.gsub(/[^a-z0-9]/, "") }

    FIELDS.each_with_object({}) do |(field, (_label, aliases)), mapping|
      index = normalized.index { it.in?(aliases) || it == field.delete("_") }
      mapping[field] = index if index && !mapping.value?(index)
    end
  end

  def sanitize_mapping(raw)
    raw.to_h.each_with_object({}) do |(field, index), mapping|
      next unless FIELDS.key?(field.to_s) && index.to_s.match?(/\A\d+\z/)

      index = index.to_i
      mapping[field.to_s] = index if index < headers.size && !mapping.value?(index)
    end
  end

  def value_for(values, field)
    # A blank input means "not fixed yet", so keep the file's value (and its error).
    override = @overrides.dig(@current_line.to_s, field).to_s.strip
    return override if override.present?

    index = mapping[field]
    return if index.nil?

    unescape(values[index].to_s.strip).presence
  end

  # Undo the formula escaping applied by AccountExport.
  def unescape(value) = value.sub(/\A'(?=\s*[=+\-@|\t\r])/, "")

  def build_row(values, line:, seen_urls:)
    @current_line = line
    errors = []
    warnings = []
    fixable = []
    attributes = {}

    TEXT_FIELDS.each { |field| attributes[field] = value_for(values, field) }
    REQUIRED_FIELDS.each do |field|
      next unless mapping.key?(field) && attributes[field].blank?

      errors << "#{self.class.field_label(field)} is missing"
      fixable << field
    end

    DATE_FIELDS.each do |field|
      raw = value_for(values, field)
      next if raw.nil?

      if (time = parse_time(raw))
        attributes[field] = time
      else
        errors << "#{self.class.field_label(field)} “#{raw}” isn’t a date"
        fixable << field
      end
    end

    if (raw = value_for(values, "offer_amount"))
      if (amount = parse_amount(raw))
        attributes["offer_amount"] = amount
      else
        errors << "Offer Amount “#{raw}” isn’t a number"
        fixable << "offer_amount"
      end
    end

    status_errors = errors.size
    apply_status(value_for(values, "status"), attributes, warnings, errors)
    if errors.size > status_errors
      # An unknown status may be fixed by choosing Offer, which also needs an amount.
      fixable.concat(errors.last == OFFER_AMOUNT_MISSING ? [ "offer_amount" ] : [ "status", "offer_amount" ])
    end

    url = attributes["application_url"]
    existing = url && @existing_leads[url]
    duplicate = nil
    action = :create

    if url && seen_urls.include?(url)
      errors << "Same application URL as an earlier row"
      fixable << "application_url"
    elsif existing
      duplicate = existing
      action = duplicate_choice == "update" ? :update : :skip
    end
    seen_urls << url if url

    lead = existing && action == :update ? existing : user.job_leads.new
    # Compare before assigning, since updating assigns onto the existing lead itself.
    changes = duplicate && changes_for(duplicate, attributes, values)
    assign(lead, attributes, values, update: action == :update)

    if errors.empty? && action != :skip && !lead.valid?(validation_context_for(lead))
      errors.concat(lead.errors.full_messages)
      lead.errors.attribute_names.map(&:to_s).each do |attribute|
        if FIELDS.key?(attribute) then fixable << attribute
        elsif attribute == "base" then fixable.concat(DATE_FIELDS.select { attributes[it] })
        end
      end
    end

    skipped = @overrides.dig(line.to_s, "skip") == "1"
    action = :skip if skipped
    # Errors from an earlier import attempt that failed to save this row.
    errors.concat(Array(@save_errors[line.to_s]) - errors) unless skipped
    action = :fix if errors.any? && !skipped
    # A differing existing lead waits for the user to choose Update or Skip.
    action = :fix if duplicate && changes.present? && duplicate_choice.nil? && !skipped

    Row.new(line:, job_lead: lead, action:, skipped:, offer_choice_needed: errors.include?(OFFER_AMOUNT_MISSING),
            errors:, warnings:, duplicate:, fixable: fixable.uniq,
            values: FIELDS.keys.index_with { value_for(values, it) }, changes:)
  end

  # What "Update Existing" would change on the existing lead: field => [old, new].
  def changes_for(existing, attributes, values)
    changes = attributes.compact.except("status").filter_map do |field, new_value|
      next unless FIELDS.key?(field) && field != "created_at"
      # Dates filled in from the status alone aren't really in the file.
      next if field.in?(DATE_FIELDS) && value_for(values, field).nil?

      old_value = existing.public_send(field)
      same = old_value.is_a?(Time) && new_value.is_a?(Time) ? old_value.to_date == new_value.to_date : old_value.to_s == new_value.to_s
      [ field, [ old_value, new_value ] ] unless same
    end.to_h

    new_tags = value_for(values, "tags").to_s.split(/[,;|]/).map { it.squish.downcase }.reject(&:blank?) - existing.tags.map(&:name)
    changes["tags"] = [ nil, new_tags ] if new_tags.any?
    changes
  end

  def duplicate_choice
    choice = @overrides.dig(@current_line.to_s, "duplicate")
    choice.in?(DUPLICATE_STRATEGIES) ? choice : on_duplicate
  end

  def assign(lead, attributes, values, update:)
    attributes = attributes.compact if update
    lead.assign_attributes(attributes.except("status"))
    lead.created_at ||= DATE_FIELDS.filter_map { lead.public_send(it) }.min if lead.new_record?
    # Set here so JobLead#update_status doesn't save the record during preview validation.
    lead.offer_at ||= lead.accepted_at || Time.current if lead.offer_amount_changed? && lead.offer_amount.present?

    tags = value_for(values, "tags").to_s.split(/[,;|]/)
    tags = lead.tags.map(&:name) + tags if update
    lead.tag_list = tags.join(",")
  end

  def apply_status(raw, attributes, warnings, errors)
    return if raw.blank?

    status = raw.downcase.squish
    if status.start_with?("interview")
      warnings << "Interviews can’t be imported, so this was set to Applied"
      status = "applied"
    end

    return if status.in?(%w[lead saved wishlist])

    unless (date_field = STATUS_DATE_FIELDS[status])
      return errors << "Status “#{raw}” isn’t recognized. Choose Lead, Applied, Offer (with an amount), Rejected, or Accepted."
    end

    if status == "offer" && attributes["offer_amount"].blank?
      unless @overrides.dig(@current_line.to_s, "offer_choice") == "applied"
        # An unreadable amount already has its own error.
        errors << OFFER_AMOUNT_MISSING unless errors.any? { it.start_with?("Offer Amount") }
        return
      end

      date_field = "applied_at"
    end

    attributes[date_field] ||= latest_time(attributes)
    attributes["applied_at"] ||= attributes[date_field] unless status == "rejected"
  end

  def latest_time(attributes) = DATE_FIELDS.filter_map { attributes[it] }.max || Time.current

  def parse_time(raw)
    if (match = NUMERIC_DATE.match(raw.strip))
      first, second, year, time = match.captures
      month, day = date_format == "dmy" ? [ second, first ] : [ first, second ]
      year = "20#{year}" if year.size == 2
      raw = [ "#{year}-#{month.rjust(2, "0")}-#{day.rjust(2, "0")}", time ].compact.join(" ")
    end

    Time.zone.parse(raw).tap { raise ArgumentError if it.nil? }
  rescue ArgumentError
    nil
  end

  def parse_amount(raw)
    multiplier = raw.strip.downcase.end_with?("k") ? 1_000 : 1
    digits = raw.gsub(/[^\d.]/, "")
    return if digits.blank? || digits.count(".") > 1

    BigDecimal(digits) * multiplier
  end
end
