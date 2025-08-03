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

ActiveRecord::Schema[8.0].define(version: 2025_08_03_120000) do
  create_table "admins", force: :cascade do |t|
    t.string "email_address"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_admins_on_email_address", unique: true
  end

  create_table "conversations", force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "participant_id"
    t.string "state", default: "intro"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.string "ip"
    t.text "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "meta", default: {}
    t.index ["participant_id"], name: "index_conversations_on_participant_id"
    t.index ["project_id"], name: "index_conversations_on_project_id"
  end

  create_table "insight_cards", force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "conversation_id"
    t.string "theme"
    t.text "jtbds"
    t.json "evidence", default: []
    t.integer "severity"
    t.integer "freq_conversations"
    t.integer "freq_messages"
    t.string "confidence_label"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_insight_cards_on_conversation_id"
    t.index ["project_id"], name: "index_insight_cards_on_project_id"
  end

  create_table "invite_links", force: :cascade do |t|
    t.integer "project_id", null: false
    t.string "token", null: false
    t.datetime "expires_at"
    t.boolean "reusable", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_invite_links_on_project_id"
    t.index ["token"], name: "index_invite_links_on_token", unique: true
  end

  create_table "messages", force: :cascade do |t|
    t.integer "conversation_id", null: false
    t.integer "role", default: 0
    t.text "content", null: false
    t.json "meta", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
  end

  create_table "participants", force: :cascade do |t|
    t.integer "project_id", null: false
    t.string "anon_hash"
    t.integer "age"
    t.json "custom_attributes", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["anon_hash"], name: "index_participants_on_anon_hash"
    t.index ["project_id"], name: "index_participants_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "name", null: false
    t.text "goal"
    t.json "must_ask", default: []
    t.json "never_ask", default: []
    t.string "tone", default: "polite_soft"
    t.json "limits", default: {"max_turns" => 12, "max_deep" => 2}
    t.string "status", default: "draft"
    t.integer "max_responses", default: 50
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "responses_count", default: 0, null: false
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "admin_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_id"], name: "index_sessions_on_admin_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "conversations", "participants"
  add_foreign_key "conversations", "projects"
  add_foreign_key "insight_cards", "conversations"
  add_foreign_key "insight_cards", "projects"
  add_foreign_key "invite_links", "projects"
  add_foreign_key "messages", "conversations"
  add_foreign_key "participants", "projects"
  add_foreign_key "sessions", "admins"
end
