class Chunk < ApplicationRecord
  belongs_to :document

  has_neighbors :embedding

  validates :position, :section_ref, :content, :token_count, :topic, :language, presence: true

  # Chunks without a vector from the current model
  scope :unembedded, ->(model = Embeddings.model) { where(embedding_model: nil).or(where.not(embedding_model: model)) }

  # Breadcrumbs give the vector context the bare chunk text lacks
  def embedding_text = "#{section_ref}\n\n#{content}"
end
