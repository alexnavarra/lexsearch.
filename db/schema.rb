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

ActiveRecord::Schema[8.1].define(version: 2026_10_16_113634) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "documents", force: :cascade do |t|
    t.string "title", null: false
    t.string "kind", default: "docs", null: false
    t.string "topic", null: false
    t.string "language", null: false
    t.string "source_format", default: "markdown", null: false
    t.string "source_url"
    t.string "source_key"
    t.text "body", null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_key"], name: "index_documents_on_source_key", unique: true
    t.index ["topic"], name: "index_documents_on_topic"
  end
end
