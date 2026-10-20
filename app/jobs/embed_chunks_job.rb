# Embeds a document's chunks in batches. Chunks that already have a vector
# from the current model are skipped, so re-running costs nothing.
class EmbedChunksJob < ApplicationJob
  BATCH_SIZE = 64

  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(document)
    model = Embeddings.model

    document.chunks.unembedded(model).in_batches(of: BATCH_SIZE) do |batch|
      chunks = batch.to_a
      vectors = Embeddings.embed_documents(chunks.map(&:embedding_text))

      Chunk.transaction do
        chunks.zip(vectors) { |chunk, vector| chunk.update_columns(embedding: vector, embedding_model: model) }
      end
    end
  end
end
