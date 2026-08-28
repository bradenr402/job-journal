class AddUniqueIndexToTaggings < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      DELETE FROM taggings
      WHERE id NOT IN (SELECT MIN(id) FROM taggings GROUP BY tag_id, job_lead_id)
    SQL

    # Superseded by the composite index below, which leads with tag_id.
    remove_index :taggings, :tag_id, if_exists: true
    add_index :taggings, [ :tag_id, :job_lead_id ], unique: true
  end

  def down
    remove_index :taggings, [ :tag_id, :job_lead_id ]
    add_index :taggings, :tag_id
  end
end
