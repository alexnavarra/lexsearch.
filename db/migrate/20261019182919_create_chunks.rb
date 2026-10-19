class CreateChunks < ActiveRecord::Migration[8.1]
  def change
    create_table :chunks do |t|
      t.references :document, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer :position, null: false
      t.string :section_ref, null: false
      t.string :heading
      t.text :content, null: false
      t.integer :token_count, null: false
      # Copied from the document so search can filter without a join
      t.string :topic, null: false
      t.string :language, null: false

      t.timestamps
    end

    add_index :chunks, %i[document_id position], unique: true
    add_index :chunks, %i[topic language]
  end
end
