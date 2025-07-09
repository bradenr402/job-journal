class ChangeNotesContentToNotNull < ActiveRecord::Migration[8.0]
  def change
    # Ensure there are no NULLs before adding the NOT NULL constraint.
    Note.where(content: nil).update_all(content: "")

    # Add NOT NULL constraint to the :content column.
    change_column_null :notes, :content, false
  end
end
