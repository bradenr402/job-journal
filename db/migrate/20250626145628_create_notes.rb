class CreateNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :notes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :notable, polymorphic: true, null: false
      t.text :content

      t.timestamps
    end

    add_index :notes, [ :notable_type, :notable_id ]
  end
end
