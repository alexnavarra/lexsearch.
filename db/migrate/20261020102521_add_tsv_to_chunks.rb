class AddTsvToChunks < ActiveRecord::Migration[8.1]
  def change
    # Generated columns allow only immutable expressions: 'russian'::regconfig is, language::regconfig is not
    config = "CASE language WHEN 'russian' THEN 'russian'::regconfig ELSE 'english'::regconfig END"

    # Postgres keeps it in sync with heading/content; a heading match (A) outranks a body match (B)
    add_column :chunks, :tsv, :virtual, type: :tsvector, stored: true, as: <<~SQL.squish
      setweight(to_tsvector(#{config}, coalesce(heading, '')), 'A') ||
      setweight(to_tsvector(#{config}, content), 'B')
    SQL
    add_index :chunks, :tsv, using: :gin
  end
end
