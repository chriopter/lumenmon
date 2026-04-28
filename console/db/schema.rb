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

ActiveRecord::Schema[8.1].define(version: 2026_04_28_000000) do
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
