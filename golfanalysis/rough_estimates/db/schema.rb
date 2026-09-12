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

ActiveRecord::Schema[8.1].define(version: 2026_09_12_055530) do
  create_table "shots", force: :cascade do |t|
    t.float "attack_angle"
    t.float "ball_speed"
    t.float "carry"
    t.string "club"
    t.float "club_path"
    t.float "club_speed"
    t.datetime "created_at", null: false
    t.float "face_to_path"
    t.text "raw", null: false
    t.integer "session_shot_number"
    t.integer "shot_number"
    t.float "smash_factor"
    t.float "total"
    t.float "total_side"
    t.integer "trackman_session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["trackman_session_id", "club"], name: "index_shots_on_trackman_session_id_and_club"
    t.index ["trackman_session_id"], name: "index_shots_on_trackman_session_id"
  end

  create_table "trackman_sessions", force: :cascade do |t|
    t.string "bay"
    t.datetime "created_at", null: false
    t.string "facility"
    t.datetime "fetched_at", null: false
    t.string "player_name"
    t.string "report_id", null: false
    t.date "session_date"
    t.integer "shot_count", default: 0, null: false
    t.text "source_url", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["session_date"], name: "index_trackman_sessions_on_session_date"
    t.index ["user_id", "report_id"], name: "index_trackman_sessions_on_user_id_and_report_id", unique: true
    t.index ["user_id"], name: "index_trackman_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "api_key", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name"
    t.string "password_digest", null: false
    t.string "player_name"
    t.datetime "updated_at", null: false
    t.index ["api_key"], name: "index_users_on_api_key", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "shots", "trackman_sessions"
  add_foreign_key "trackman_sessions", "users"
end
