class Chunk < ApplicationRecord
  belongs_to :document
  has_many :cards, dependent: nil # FK nullifies chunk_id; cards outlive re-chunking

  has_neighbors :embedding

  # Set by FulltextSearch: matched fragment with FulltextSearch::MARK_* around hits
  attribute :snippet, :string

  validates :position, :section_ref, :content, :token_count, :topic, :language, presence: true

  # Chunks without a vector from the current model
  scope :unembedded, ->(model = Embeddings.model) { where(embedding_model: nil).or(where.not(embedding_model: model)) }

  # Breadcrumbs give the vector context the bare chunk text lacks
  def embedding_text = "#{section_ref}\n\n#{content}"
end
