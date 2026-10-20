class Document < ApplicationRecord
  # Chunks are deleted by the FK's ON DELETE CASCADE, no Rails callback needed
  has_many :chunks, -> { order(:position) }, inverse_of: :document
  has_many :cards, -> { order(:id) }, inverse_of: :document

  # String-backed enums: readable values in SQL, validate: true adds errors instead of raising
  enum :kind, { docs: "docs", book: "book", notes: "notes", article: "article" }, validate: true
  enum :language, { english: "english", russian: "russian" }, prefix: true, validate: true
  enum :source_format, { markdown: "markdown", html: "html", pdf: "pdf" }, validate: true
  enum :status, { pending: "pending", indexing: "indexing", indexed: "indexed", failed: "failed" }, validate: true

  normalizes :topic, with: ->(topic) { topic.strip.downcase }
  normalizes :source_url, with: ->(url) { url.strip.presence }

  validates :title, :topic, :body, presence: true
  validates :source_key, uniqueness: true, allow_nil: true

  def self.topics = distinct.order(:topic).pluck(:topic)
end
