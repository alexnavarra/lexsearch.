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

ActiveRecord::Schema[8.1].define(version: 2026_10_21_072055) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "attempts", force: :cascade do |t|
    t.bigint "card_id", null: false
    t.text "answer", default: "", null: false
    t.string "status", default: "pending", null: false
    t.integer "score"
    t.jsonb "verdict", default: {}, null: false
    t.string "llm_model"
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_attempts_on_card_id"
    t.index ["status"], name: "index_attempts_on_status"
  end

  create_table "cards", force: :cascade do |t|
    t.bigint "document_id", null: false
    t.bigint "chunk_id"
    t.text "prompt"
    t.text "reference_answer"
    t.string "kind"
    t.string "difficulty"
    t.string "status", default: "valid", null: false
    t.string "llm_model", null: false
    t.jsonb "validation_errors", default: {}, null: false
    t.vector "prompt_embedding", limit: 1024
    t.string "embedding_model"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.float "ease", default: 2.5, null: false
    t.integer "interval_days", default: 0, null: false
    t.integer "repetitions", default: 0, null: false
    t.datetime "due_at"
    t.index ["chunk_id"], name: "index_cards_on_chunk_id"
    t.index ["document_id"], name: "index_cards_on_document_id"
    t.index ["due_at"], name: "index_cards_on_due_at"
    t.index ["status"], name: "index_cards_on_status"
  end

  create_table "chunks", force: :cascade do |t|
    t.bigint "document_id", null: false
    t.integer "position", null: false
    t.string "section_ref", null: false
    t.string "heading"
    t.text "content", null: false
    t.integer "token_count", null: false
    t.string "topic", null: false
    t.string "language", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.vector "embedding", limit: 1024
    t.string "embedding_model"
    t.virtual "tsv", type: :tsvector, as: "(setweight(to_tsvector(\nCASE language\n    WHEN 'russian'::text THEN 'russian'::regconfig\n    ELSE 'english'::regconfig\nEND, (COALESCE(heading, ''::character varying))::text), 'A'::\"char\") || setweight(to_tsvector(\nCASE language\n    WHEN 'russian'::text THEN 'russian'::regconfig\n    ELSE 'english'::regconfig\nEND, content), 'B'::\"char\"))", stored: true
    t.index ["document_id", "position"], name: "index_chunks_on_document_id_and_position", unique: true
    t.index ["embedding"], name: "index_chunks_on_embedding", opclass: :vector_cosine_ops, using: :hnsw
    t.index ["topic", "language"], name: "index_chunks_on_topic_and_language"
    t.index ["tsv"], name: "index_chunks_on_tsv", using: :gin
  end

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

  create_table "llm_calls", force: :cascade do |t|
    t.string "purpose", null: false
    t.string "provider", null: false
    t.string "model", null: false
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.integer "duration_ms"
    t.string "status", null: false
    t.string "stop_reason"
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_llm_calls_on_created_at"
  end

  create_table "questions", force: :cascade do |t|
    t.text "text", null: false
    t.jsonb "filters", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.text "answer"
    t.bigint "chunk_ids", default: [], null: false, array: true
    t.jsonb "citations", default: {}, null: false
    t.string "llm_model"
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "attempts", "cards", on_delete: :cascade
  add_foreign_key "cards", "chunks", on_delete: :nullify
  add_foreign_key "cards", "documents", on_delete: :cascade
  add_foreign_key "chunks", "documents", on_delete: :cascade
end
