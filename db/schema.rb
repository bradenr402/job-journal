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

ActiveRecord::Schema[8.0].define(version: 2025_06_26_145628) do
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
    t.integer "status", default: 0, null: false
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["archived_at"], name: "index_job_leads_on_archived_at"
    t.index ["status"], name: "index_job_leads_on_status"
    t.index ["user_id"], name: "index_job_leads_on_user_id"
    t.check_constraint "offer_amount IS NULL OR offer_amount >= 0", name: "offer_amount_non_negative"
  end

  create_table "notes", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "notable_type", null: false
    t.integer "notable_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["notable_type", "notable_id"], name: "index_notes_on_notable"
    t.index ["notable_type", "notable_id"], name: "index_notes_on_notable_type_and_notable_id"
    t.index ["user_id"], name: "index_notes_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "job_leads", "users"
  add_foreign_key "notes", "users"
  add_foreign_key "sessions", "users"
end
