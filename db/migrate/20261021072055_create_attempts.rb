class CreateAttempts < ActiveRecord::Migration[8.1]
  def change
    create_table :attempts do |t|
      t.references :card, null: false, foreign_key: { on_delete: :cascade }
      t.text :answer, null: false, default: ""
      t.string :status, null: false, default: "pending"
      t.integer :score
      # { "covered" => [...], "missed" => [...], "incorrect" => [...], "feedback" => "..." }
      t.jsonb :verdict, null: false, default: {}
      t.string :llm_model
      t.text :error

      t.timestamps
    end
    add_index :attempts, :status
  end
end
