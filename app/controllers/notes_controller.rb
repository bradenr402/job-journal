class NotesController < ApplicationController
  before_action :set_note, only: %i[ show edit update destroy ]

  # GET /notes
  def index
    @selected_note_type = valid_note_type(use_user_setting: true)
    @selected_notable_type = valid_notable_type

    scope =
      Current.user.notes
        .includes(notable: :job_lead)
        .order(updated_at: :desc)
        .yield_self { |scope| @selected_notable_type.present? ? scope.where(notable_type: @selected_notable_type) : scope }

    @notes =
      case @selected_note_type
      when "active"
        scope
          .where.not(
            notable_type: "JobLead",
            notable_id: Current.user.job_leads.archived.select(:id)
          )
      when "archived"
        scope.where(
          notable_type: "JobLead",
          notable_id: Current.user.job_leads.archived.select(:id)
        )
      else
        scope
      end
  end

  # GET /notes/new
  def new
    @note = Note.new
    if params[:notable_type].present? && params[:notable_id].present?
      verify_notable_ownership!(params[:notable_type], params[:notable_id])
      @note.notable_type = params[:notable_type]
      @note.notable_id = params[:notable_id]
    end
  end

  def show
    @notable = @note.notable
  end

  # GET /notes/1/edit
  def edit
  end

  # POST /notes
  def create
    verify_notable_ownership!(note_params[:notable_type], note_params[:notable_id])
    @note = Current.user.notes.build(note_params)

    if @note.save
      redirect_to @note, success: "Note was successfully created."
    else
      render :new, status: :unprocessable_content, error: "Failed to create the note."
    end
  end

  # PATCH/PUT /notes/1
  def update
    verify_notable_ownership!(note_params[:notable_type], note_params[:notable_id])

    if @note.update(note_params)
      redirect_to @note, success: "Note was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content, error: "Failed to update the note."
    end
  end

  # DELETE /notes/1
  def destroy
    if @note.destroy
      redirect_to @note.notable, success: "Note was successfully deleted.", status: :see_other
    else
      redirect_to @note, error: "Failed to delete the note.", status: :unprocessable_content
    end
  end

  private

  def set_note
    @note = Current.user.notes.includes(notable: :job_lead).find(params.expect(:id))
  rescue ActiveRecord::RecordNotFound
    raise # Let config.exceptions_app handle the error
  end

  def note_params
    params.expect(note: [ :content, :notable_type, :notable_id ])
  end

  # Ensures a note can only be attached to a notable owned by the current user.
  def verify_notable_ownership!(notable_type, notable_id)
    return if notable_type.blank? && notable_id.blank?

    owned =
      case notable_type
      when "JobLead" then Current.user.job_leads.exists?(notable_id)
      when "Interview" then Current.user.interviews.exists?(notable_id)
      else false
      end

    raise ActiveRecord::RecordNotFound unless owned
  end
end
