class CreateLlmCalls < ActiveRecord::Migration[8.1]
  def change
    # One row per LLM request: what it was for, what it cost, how it ended
    create_table :llm_calls do |t|
      t.string :purpose, null: false
      t.string :provider, null: false
      t.string :model, null: false
      t.integer :input_tokens
      t.integer :output_tokens
      t.integer :duration_ms
      t.string :status, null: false
      t.string :stop_reason
      t.text :error

      t.timestamps
    end

    add_index :llm_calls, :created_at
  end
end
