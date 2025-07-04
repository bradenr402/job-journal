class NotesController < ApplicationController
  before_action :set_note, only: %i[ show edit update destroy ]

  # GET /notes/new
  def new
    @note = Note.new
    if params[:notable_type].present? && params[:notable_id].present?
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
    @note = Current.user.notes.build(note_params)

    if @note.save
      redirect_to @note.notable, success: 'Note was successfully created.'
    else
      render :new, status: :unprocessable_entity, error: 'Failed to create the note.'
    end
  end

  # PATCH/PUT /notes/1
  def update
    if @note.update(note_params)
      redirect_to @note, success: 'Note was successfully updated.', status: :see_other
    else
      render :edit, status: :unprocessable_entity, error: 'Failed to update the note.'
    end
  end

  # DELETE /notes/1
  def destroy
    if @note.destroy
      redirect_to @note.notable, success: 'Note was successfully destroyed.', status: :see_other
    else
      redirect_to @note, error: 'Failed to destroy the note.', status: :unprocessable_entity
    end
  end

  private

  def set_note
    @note = Current.user.notes.find(params.expect(:id))
  rescue ActiveRecord::RecordNotFound
    redirect_back fallback_location: root_path, alert: 'Note not found.', status: :not_found
  end

  def note_params
    params.expect(note: [ :content, :notable_type, :notable_id ])
  end
end
