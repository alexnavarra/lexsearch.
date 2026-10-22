# Rebuilds a document's chunks from its current body and embeds them. Safe to run repeatedly.
# A PDF without a body gets it extracted from the attached file first.
class IndexDocumentJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(document)
    document.update!(status: "indexing", index_error: nil)
    extract_pdf(document) if document.pdf? && document.body.blank?
    pieces = Chunker.new(document.body, title: document.title).call
    now = Time.current

    Document.transaction do
      vectors = reusable_vectors(document)
      Chunk.where(document:).delete_all # association delete_all would nullify, not delete
      Chunk.insert_all!(pieces.each_with_index.map { |piece, position|
        piece.to_h.merge(document_id: document.id, position:, topic: document.topic,
                         language: document.language, created_at: now, updated_at: now,
                         **vectors.fetch([ piece.section_ref, piece.content ], { embedding: nil, embedding_model: nil }))
      }) if pieces.any?
    end

    # Outside the transaction: slow HTTP must not hold a DB transaction open
    EmbedChunksJob.perform_now(document)
    document.update!(status: "indexed")
  rescue PdfExtractor::Error => e
    mark_failed(document, "PDF: #{e.message}") # a broken file will not get better on retry
  rescue StandardError => e
    mark_failed(document, "#{e.class}: #{e.message}") if document&.persisted?
    raise
  end

  private

  # Vectors of current chunks keyed by their text: unchanged chunks keep them, only new text is embedded
  def reusable_vectors(document)
    model = Embeddings.model
    Chunk.where(document:, embedding_model: model).pluck(:section_ref, :content, :embedding)
         .to_h { |ref, content, embedding| [ [ ref, content ], { embedding:, embedding_model: model } ] }
  end

  # update_columns: the document may be invalid (e.g. empty body); callbacks are skipped, so refresh by hand
  def mark_failed(document, error)
    document.update_columns(status: "failed", index_error: error.truncate(1_000))
    document.broadcast_refresh
  end

  def extract_pdf(document)
    raise PdfExtractor::Error, "the PDF file is missing" unless document.source_file.attached?

    document.update!(body: PdfExtractor.new(document.source_file.download).call)
  end
end
