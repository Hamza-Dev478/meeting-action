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

ActiveRecord::Schema[8.1].define(version: 2026_10_29_150005) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_items", force: :cascade do |t|
    t.bigint "meeting_id", null: false
    t.bigint "suggestion_id", null: false
    t.bigint "accepted_by_id", null: false
    t.text "description", null: false
    t.string "owner"
    t.date "due_date"
    t.text "source_quote", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["accepted_by_id"], name: "index_action_items_on_accepted_by_id"
    t.index ["meeting_id", "created_at"], name: "index_action_items_on_meeting_id_and_created_at"
    t.index ["suggestion_id"], name: "index_action_items_on_suggestion_id", unique: true
  end

  create_table "meetings", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "author_id", null: false
    t.string "title", null: false
    t.text "notes", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_meetings_on_author_id"
    t.index ["organization_id", "created_at"], name: "index_meetings_on_organization_id_and_created_at"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_organizations_on_name", unique: true
  end

  create_table "suggestion_generations", force: :cascade do |t|
    t.bigint "meeting_id", null: false
    t.bigint "requested_by_id", null: false
    t.string "status", default: "running", null: false
    t.string "provider", null: false
    t.string "model"
    t.string "prompt_version", null: false
    t.string "error_code"
    t.string "error_message"
    t.integer "suggestion_count", default: 0, null: false
    t.integer "rejected_count", default: 0, null: false
    t.jsonb "validation_report", default: {}, null: false
    t.text "raw_response"
    t.datetime "started_at", null: false
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["meeting_id"], name: "index_suggestion_generations_on_meeting_id"
    t.index ["meeting_id"], name: "index_suggestion_generations_one_running_per_meeting", unique: true, where: "((status)::text = 'running'::text)"
    t.index ["requested_by_id"], name: "index_suggestion_generations_on_requested_by_id"
    t.check_constraint "status::text = ANY (ARRAY['running'::character varying, 'succeeded'::character varying, 'failed'::character varying]::text[])", name: "suggestion_generations_status_check"
  end

  create_table "suggestions", force: :cascade do |t|
    t.bigint "meeting_id", null: false
    t.bigint "suggestion_generation_id", null: false
    t.string "status", default: "pending", null: false
    t.text "description", null: false
    t.string "owner"
    t.date "due_date"
    t.text "source_quote", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["meeting_id", "status"], name: "index_suggestions_on_meeting_id_and_status"
    t.index ["suggestion_generation_id"], name: "index_suggestions_on_suggestion_generation_id"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'accepted'::character varying, 'dismissed'::character varying, 'superseded'::character varying]::text[])", name: "suggestions_status_check"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.string "api_token_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["api_token_digest"], name: "index_users_on_api_token_digest", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
  end

  add_foreign_key "action_items", "meetings"
  add_foreign_key "action_items", "suggestions"
  add_foreign_key "action_items", "users", column: "accepted_by_id"
  add_foreign_key "meetings", "organizations"
  add_foreign_key "meetings", "users", column: "author_id"
  add_foreign_key "suggestion_generations", "meetings"
  add_foreign_key "suggestion_generations", "users", column: "requested_by_id"
  add_foreign_key "suggestions", "meetings"
  add_foreign_key "suggestions", "suggestion_generations"
  add_foreign_key "users", "organizations"
end
