# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_12_08_053247) do
  create_table "interviews", force: :cascade do |t|
    t.integer "job_lead_id", null: false
    t.string "interviewer", null: false
    t.datetime "scheduled_at", null: false
    t.string "location"
    t.integer "rating"
    t.string "call_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_lead_id"], name: "index_interviews_on_job_lead_id"
    t.check_constraint "(rating BETWEEN 1 AND 5) OR rating IS NULL", name: "rating_between_1_and_5"
  end

  create_table "job_leads", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "company", null: false
    t.string "title", null: false
    t.text "application_url"
    t.text "source"
    t.text "contact"
    t.string "salary"
    t.decimal "offer_amount", precision: 12, scale: 2
    t.string "location"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "applied_at"
    t.datetime "offer_at"
    t.datetime "rejected_at"
    t.datetime "accepted_at"
    t.index ["accepted_at"], name: "index_job_leads_on_accepted_at"
    t.index ["applied_at"], name: "index_job_leads_on_applied_at"
    t.index ["archived_at"], name: "index_job_leads_on_archived_at"
    t.index ["offer_at"], name: "index_job_leads_on_offer_at"
    t.index ["rejected_at"], name: "index_job_leads_on_rejected_at"
    t.index ["user_id"], name: "index_job_leads_on_user_id"
    t.check_constraint "offer_amount IS NULL OR offer_amount >= 0", name: "offer_amount_non_negative"
  end

  create_table "notes", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "notable_type", null: false
    t.integer "notable_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["notable_type", "notable_id"], name: "index_notes_on_notable"
    t.index ["notable_type", "notable_id"], name: "index_notes_on_notable_type_and_notable_id"
    t.index ["user_id"], name: "index_notes_on_user_id"
  end

  create_table "passkeys_rails_agents", force: :cascade do |t|
    t.string "username", null: false
    t.string "authenticatable_type"
    t.integer "authenticatable_id"
    t.string "webauthn_identifier"
    t.datetime "registered_at"
    t.datetime "last_authenticated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["authenticatable_type", "authenticatable_id"], name: "index_passkeys_rails_agents_on_authenticatable", unique: true
    t.index ["username"], name: "index_passkeys_rails_agents_on_username", unique: true
  end

  create_table "passkeys_rails_passkeys", force: :cascade do |t|
    t.string "identifier"
    t.string "public_key"
    t.integer "sign_count"
    t.integer "agent_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_passkeys_rails_passkeys_on_agent_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "taggings", force: :cascade do |t|
    t.integer "job_lead_id", null: false
    t.integer "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_lead_id"], name: "index_taggings_on_job_lead_id"
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
  end

  create_table "tags", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "user_id"], name: "index_tags_on_name_and_user_id", unique: true
    t.index ["user_id"], name: "index_tags_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "settings", default: "{}", null: false
    t.string "name"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "interviews", "job_leads"
  add_foreign_key "job_leads", "users"
  add_foreign_key "notes", "users"
  add_foreign_key "passkeys_rails_passkeys", "passkeys_rails_agents", column: "agent_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "taggings", "job_leads"
  add_foreign_key "taggings", "tags"
  add_foreign_key "tags", "users"
end
