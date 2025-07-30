class AddSettingsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :settings, :text, default: '{}', null: false
  end
end
