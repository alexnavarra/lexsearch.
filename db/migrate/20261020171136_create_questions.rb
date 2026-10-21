class CreateQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :questions do |t|
      t.text :text, null: false
      # Search filters the question was asked with: topic, kind, language
      t.jsonb :filters, null: false, default: {}
      t.string :status, null: false, default: "pending"
      t.text :answer
      # Sources shown to the LLM, in [S1..Sn] order; ids only, chunks may be re-indexed later
      t.bigint :chunk_ids, array: true, null: false, default: []
      # { "cited" => [1, 3], "invalid" => [7] }: which [Sn] the answer used, which do not exist
      t.jsonb :citations, null: false, default: {}
      t.string :llm_model
      t.text :error

      t.timestamps
    end
  end
end
