class CreateCards < ActiveRecord::Migration[8.1]
  def change
    create_table :cards do |t|
      t.references :document, null: false, foreign_key: { on_delete: :cascade }
      # Re-chunking deletes chunks; the card survives and keeps its document
      t.references :chunk, foreign_key: { on_delete: :nullify }
      # Blank only for needs_review cards built from broken LLM output
      t.text :prompt
      t.text :reference_answer
      t.string :kind
      t.string :difficulty
      t.string :status, null: false, default: "valid"
      # Model that wrote the card; "fake" cards are replaced once a real LLM is configured
      t.string :llm_model, null: false
      t.jsonb :validation_errors, null: false, default: {}
      # Embedding of the prompt, used to drop near-duplicate questions
      t.vector :prompt_embedding, limit: 1024
      t.string :embedding_model

      t.timestamps
    end

    add_index :cards, :status
  end
end
