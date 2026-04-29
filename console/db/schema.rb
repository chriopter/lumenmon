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

ActiveRecord::Schema[8.1].define(version: 2026_04_29_010000) do
  create_table "messages", force: :cascade do |t|
    t.string "agent_id", null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.string "mail_from", default: "unknown", null: false
    t.string "mail_to", default: "", null: false
    t.text "raw_content"
    t.boolean "read", default: false, null: false
    t.datetime "received_at", null: false
    t.string "subject", default: "(no subject)", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id", "received_at"], name: "index_messages_on_agent_id_and_received_at"
    t.index ["read"], name: "index_messages_on_read"
  end

  create_table "metric_observations", force: :cascade do |t|
    t.string "agent_id", null: false
    t.datetime "created_at", null: false
    t.string "data_type", default: "TEXT", null: false
    t.integer "interval", default: 60, null: false
    t.float "max"
    t.string "metric_name", null: false
    t.float "min"
    t.datetime "observed_at", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.float "warn_max"
    t.float "warn_min"
    t.index ["agent_id", "metric_name", "observed_at"], name: "idx_on_agent_id_metric_name_observed_at_03480a0f0e"
    t.index ["observed_at"], name: "index_metric_observations_on_observed_at"
  end

  create_table "metric_samples", force: :cascade do |t|
    t.string "agent_id", null: false
    t.datetime "created_at", null: false
    t.string "data_type", default: "TEXT", null: false
    t.integer "interval", default: 60, null: false
    t.float "max"
    t.string "metric_name", null: false
    t.float "min"
    t.datetime "observed_at", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.float "warn_max"
    t.float "warn_min"
    t.index ["agent_id", "metric_name"], name: "index_metric_samples_on_agent_id_and_metric_name", unique: true
    t.index ["agent_id"], name: "index_metric_samples_on_agent_id"
  end
end
