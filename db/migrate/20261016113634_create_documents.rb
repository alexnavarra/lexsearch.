class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.string :title, null: false
      t.string :kind, null: false, default: "docs"
      t.string :topic, null: false
      t.string :language, null: false # PG text search config name: english | russian
      t.string :source_format, null: false, default: "markdown"
      t.string :source_url
      t.string :source_key # stable id for idempotent seeds, e.g. "rails_guides/active_record_querying"
      t.text :body, null: false # always normalized Markdown
      t.string :status, null: false, default: "pending"

      t.timestamps
    end

    add_index :documents, :topic
    add_index :documents, :source_key, unique: true
  end
end
