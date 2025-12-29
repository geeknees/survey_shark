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

ActiveRecord::Schema[8.1].define(version: 2025_12_29_162034) do
  create_table "admins", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address"
    t.string "password_digest"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_admins_on_email_address", unique: true
  end

  create_table "conversations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.string "ip"
    t.json "meta", default: {}
    t.integer "participant_id"
    t.integer "project_id", null: false
    t.datetime "started_at"
    t.string "state", default: "intro"
    t.datetime "updated_at", null: false
    t.text "user_agent"
    t.index ["participant_id"], name: "index_conversations_on_participant_id"
    t.index ["project_id"], name: "index_conversations_on_project_id"
  end

  create_table "insight_cards", force: :cascade do |t|
    t.string "confidence_label"
    t.integer "conversation_id"
    t.datetime "created_at", null: false
    t.json "evidence", default: []
    t.integer "freq_conversations"
    t.integer "freq_messages"
    t.text "jtbds"
    t.integer "project_id", null: false
    t.integer "severity"
    t.string "theme"
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_insight_cards_on_conversation_id"
    t.index ["project_id"], name: "index_insight_cards_on_project_id"
  end

  create_table "invite_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.integer "project_id", null: false
    t.boolean "reusable", default: true
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_invite_links_on_project_id"
    t.index ["token"], name: "index_invite_links_on_token", unique: true
  end

  create_table "messages", force: :cascade do |t|
    t.text "content", null: false
    t.integer "conversation_id", null: false
    t.datetime "created_at", null: false
    t.json "meta", default: {}
    t.integer "role", default: 0
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
  end

  create_table "participants", force: :cascade do |t|
    t.integer "age"
    t.string "anon_hash"
    t.datetime "created_at", null: false
    t.json "custom_attributes", default: {}
    t.integer "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["anon_hash"], name: "index_participants_on_anon_hash"
    t.index ["project_id"], name: "index_participants_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "goal"
    t.text "initial_question", default: "まず、日常生活で感じている課題や不便なことを3つまで教えてください。どんな小さなことでも構いません。"
    t.json "limits", default: {"max_turns" => 12, "max_deep" => 5}
    t.integer "max_responses", default: 50
    t.json "must_ask", default: []
    t.string "name", null: false
    t.json "never_ask", default: []
    t.integer "responses_count", default: 0, null: false
    t.string "status", default: "draft"
    t.string "tone", default: "polite_soft"
    t.datetime "updated_at", null: false
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "admin_id", null: false
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["admin_id"], name: "index_sessions_on_admin_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
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
