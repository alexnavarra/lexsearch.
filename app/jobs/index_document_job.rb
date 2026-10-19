# Rebuilds a document's chunks from its current body. Safe to run repeatedly.
class IndexDocumentJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(document)
    document.update!(status: "indexing")
    pieces = Chunker.new(document.body, title: document.title).call
    now = Time.current

    Document.transaction do
      Chunk.where(document:).delete_all # association delete_all would nullify, not delete
      Chunk.insert_all!(pieces.each_with_index.map { |piece, position|
        piece.to_h.merge(document_id: document.id, position:, topic: document.topic,
                         language: document.language, created_at: now, updated_at: now)
      }) if pieces.any?
      document.update!(status: "indexed")
    end
  rescue StandardError
    document.update_columns(status: "failed") if document&.persisted?
    raise
  end
end
