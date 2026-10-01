class ImportsController < ApplicationController
  ROW_CHOICES = %w[ skip duplicate offer_choice ].freeze
  PAGES = %w[ columns review summary ].freeze

  before_action :set_draft, only: %i[ columns review summary update ]

  rate_limit to: 10, within: 1.minute, only: :create, by: -> { Current.user.id },
    with: -> { redirect_to new_account_import_path, alert: "Too many uploads. Try again in a minute." }
  # Higher, since every column or field change sends a request.
  rate_limit to: 120, within: 1.minute, only: :update, by: -> { Current.user.id }, with: -> { head :too_many_requests }

  rescue_from ImportDraft::NotFound do
    if params[:step] == "import" && (batch_tag = Rails.cache.read(finished_key))
      # A second click on Import after the first one finished.
      redirect_to job_leads_path(tags: batch_tag, job_lead_state: "all"), notice: "That import has already finished.", status: :see_other
    else
      redirect_to new_account_import_path, alert: "That import has expired. Upload your file again.", status: :see_other
    end
  end

  def new
  end

  def create
    raise JobLeadImport::Error, "Choose a CSV file to import." if params[:file].blank?

    import = JobLeadImport.new(user: Current.user, csv: uploaded_csv)
    draft = ImportDraft.create(
      user: Current.user,
      csv: import.csv_content,
      filename: params[:file].original_filename,
      row_count: import.row_count,
      mapping: {},
      auto_mapping: {},
      overrides: {}
    )

    redirect_to columns_account_import_path(draft), status: :see_other
  rescue JobLeadImport::Error => e
    @error = e.message
    render :new, status: :unprocessable_content
  end

  def columns
  end

  def review
    redirect_to columns_account_import_path(@draft), alert: missing_columns_message if @import.missing_required_fields.any?
  end

  def summary
    if @import.missing_required_fields.any?
      redirect_to columns_account_import_path(@draft), alert: missing_columns_message
    elsif @import.summary[:fix].positive?
      redirect_to review_account_import_path(@draft), alert: unresolved_message
    end
  end

  # Saves changes from either step, then refreshes the page, moves to another
  # step, or imports. (One endpoint keeps the per-form CSRF token valid for every button.)
  def update
    row_change = params[:rows] || params[:bulk_duplicate] || params[:bulk_skip]
    # Counts saved by the last request, so the old rows needn't be checked again.
    before = (@draft[:summary] || @import.summary).to_h.symbolize_keys if row_change
    @draft.update(draft_changes)
    @import = @draft.import
    @draft.update(summary: @import.summary)
    @status = status_message(before) if before
    @page = params[:page].presence_in(PAGES) || "summary"

    case params[:step]
    when "import" then import
    when "columns" then redirect_to columns_account_import_path(@draft), status: :see_other
    when "review"
      if @import.missing_required_fields.any?
        @error = missing_columns_message
        render :columns, status: :unprocessable_content
      elsif @page == "columns" && !@import.needs_review?
        # Nothing to review, so go straight to the summary.
        redirect_to summary_account_import_path(@draft), status: :see_other
      else
        redirect_to review_account_import_path(@draft), status: :see_other
      end
    when "summary"
      if @import.summary[:fix].positive?
        @error = unresolved_message
        render :review, status: :unprocessable_content
      else
        redirect_to summary_account_import_path(@draft), status: :see_other
      end
    else
      # Including a row with problems on Summary sends the user to Review to fix it.
      if @page == "summary" && @import.summary[:fix].positive?
        return redirect_to review_account_import_path(@draft), alert: unresolved_message, status: :see_other
      end

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to url_for(action: @page, id: @draft), status: :see_other }
      end
    end
  end

  private

  def failure_summary(result)
    # Errors can quote CSV values, and flash messages render as HTML.
    failures = result.failed_rows.first(3).map { "row #{it.line} (#{ERB::Util.h(it.errors.last.to_s.truncate(80))})" }
    extra = result.failed_rows.size - failures.size
    "#{failures.to_sentence}#{" and #{extra} more" if extra.positive?}"
  end

  # Only real fields and column positions are saved to the draft.
  def permitted_mapping
    columns = 0...@import.headers.size
    params[:mapping].to_unsafe_h.to_h
      .select { |field, index| field.in?(JobLeadImport::FIELDS) && index.to_s.match?(/\A\d+\z/) && index.to_i.in?(columns) }
  end

  # Only real rows and known fields are saved to the draft.
  def permitted_rows
    lines = (2..@import.row_count + 1).map(&:to_s)
    params[:rows].to_unsafe_h.to_h
      .select { |line, fields| line.in?(lines) && fields.is_a?(Hash) }
      .transform_values do |fields|
        fields.slice(*JobLeadImport::FIELDS.keys, *ROW_CHOICES).transform_values { it.to_s.first(500) }
      end
  end

  def finished_key = "#{ImportDraft.key(Current.user, params[:id])}/finished"

  def set_draft
    @draft = ImportDraft.find(user: Current.user, id: params.expect(:id))
    @import = @draft.import
  end

  def draft_changes
    changes = {}
    overrides = @draft[:overrides] || {}

    # The form sends column => field; the importer works with field => column.
    if params.key?(:column_mapping)
      params[:mapping] = params[:column_mapping].to_unsafe_h.compact_blank.to_h { |index, field| [ field, index ] }
    end

    # Auto-Match replaces every choice (the page confirms first if any were made by hand).
    if params[:auto_match]
      suggested = @import.suggested_mapping
      params[:mapping] = suggested.transform_values(&:to_s)
      changes[:auto_mapping] = suggested
    end

    if params[:clear_mapping]
      params[:mapping] = {}
      changes[:auto_mapping] = {}
    end

    changes[:show_unmatched] = params[:show_unmatched] if params.key?(:show_unmatched)

    if params.key?(:mapping)
      changes[:mapping] = permitted_mapping

      # Fixes typed for a field no longer apply once it reads from a different column.
      remapped = JobLeadImport::FIELDS.keys.reject { changes[:mapping][it].to_s == @draft[:mapping].to_h[it].to_s }
      overrides = overrides.transform_values { it.except(*remapped) } if remapped.any?
    end

    changes[:date_format] = params[:date_format] if params.key?(:date_format)

    if params[:bulk_duplicate].in?(JobLeadImport::DUPLICATE_STRATEGIES)
      # Record the choice on each differing existing lead, the same as clicking its buttons.
      @import.rows.select { it.duplicate? && it.changes.present? }.each do |row|
        choice = params[:bulk_duplicate] == "update" ? { "duplicate" => "update", "skip" => "0" } : { "skip" => "1" }
        overrides[row.line.to_s] = overrides.fetch(row.line.to_s, {}).merge(choice)
      end
    end

    if params[:bulk_skip] == "problems"
      @import.rows.select { it.action == :fix && !it.duplicate? }.each do |row|
        overrides[row.line.to_s] = overrides.fetch(row.line.to_s, {}).merge("skip" => "1")
      end
    end

    if params[:rows]
      rows = permitted_rows
      overrides = overrides.deep_merge(rows)
      # A row the user just changed gets a fresh check instead of its old save error.
      changes[:save_errors] = (@draft[:save_errors] || {}).except(*rows.keys)
    end
    # New columns or date reading re-check every row, so earlier save errors no longer apply.
    changes[:save_errors] = {} if params.key?(:mapping) || params.key?(:date_format)
    changes[:overrides] = JSON.parse(overrides.to_json)
    changes
  end

  def status_message(before)
    after = @import.summary
    return "Row checks updated." if after == before

    parts = []
    parts << "#{helpers.pluralize(after[:create], "row")} ready" if after[:create] != before[:create]
    parts << "#{after[:update]} to update" if after[:update] != before[:update]
    parts << "#{after[:skip]} skipped" if after[:skip] != before[:skip]
    parts << "#{after[:fix].zero? ? "no" : after[:fix]} #{"row".pluralize(after[:fix])} left to fix"
    "#{parts.to_sentence.upcase_first}."
  end

  def unresolved_message
    fix = @import.summary[:fix]
    "Fix or skip #{fix == 1 ? "the row" : "all #{fix} rows"} that need attention to continue."
  end

  def missing_columns_message
    "Choose a column for #{@import.missing_required_fields.map { JobLeadImport.field_label(it) }.to_sentence} to continue."
  end

  def import
    result = @import.import!

    if (result.created + result.updated).zero?
      # Nothing saved, so keep the draft and let the user fix what failed.
      @draft.update(save_errors: result.failed_rows.to_h { [ it.line.to_s, it.errors ] })
      @import = @draft.import
      @error = "Nothing was imported. Couldn’t save #{failure_summary(result)}.".html_safe
      return render :review, status: :unprocessable_content
    end

    Rails.cache.write(finished_key, result.batch_tag, expires_in: 1.hour)
    @draft.destroy

    message = "Imported #{helpers.pluralize(result.created, "new job lead")}"
    message += " and updated #{result.updated}" if result.updated.positive?
    if result.skipped_rows.any?
      lines = result.skipped_rows.map(&:line)
      message += ". Skipped #{lines.size == 1 ? "row" : "rows"} #{lines.first(10).to_sentence}#{" and #{lines.size - 10} more" if lines.size > 10}"
    end

    message += ". Couldn’t save #{failure_summary(result)}" if result.failed_rows.any?

    flash[result.failed_rows.any? ? :alert : :success] = "#{message}."
    redirect_to job_leads_path(tags: result.batch_tag, job_lead_state: "all"), status: :see_other
  rescue JobLeadImport::Error => e
    @error = e.message
    render(@import.summary[:fix].positive? ? :review : :summary, status: :unprocessable_content)
  end

  def uploaded_csv
    file = params[:file]
    raise JobLeadImport::Error, "Choose a CSV file to import." unless file.respond_to?(:read)
    raise JobLeadImport::Error, "The file is larger than 1 MB." if file.size > JobLeadImport::MAX_BYTES
    raise JobLeadImport::Error, "Choose a .csv file." unless File.extname(file.original_filename.to_s).casecmp?(".csv")

    file.read
  end
end
