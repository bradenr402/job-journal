class CreatePasskeys < ActiveRecord::Migration[8.0]
  def change
    create_table :passkeys do |t|
      t.references :user, null: false, foreign_key: true
      t.string :identifier, null: false
      t.text :public_key, null: false
      t.integer :sign_count, null: false, default: 0
      t.string :name, null: false
      t.datetime :last_used_at
      t.json :transports

      t.timestamps
    end
    
    add_index :passkeys, :identifier, unique: true
    add_index :passkeys, [:user_id, :name]
  end
end
