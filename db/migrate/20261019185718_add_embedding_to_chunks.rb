class AddEmbeddingToChunks < ActiveRecord::Migration[8.1]
  def change
    # Column size must match the model (bge-m3: 1024); changing models means a new migration
    add_column :chunks, :embedding, :vector, limit: 1024
    # Vectors from different models are not comparable, so keep the model name next to each one
    add_column :chunks, :embedding_model, :string
    add_index :chunks, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end
end
