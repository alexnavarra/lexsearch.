class Question < ApplicationRecord
  FILTERS = %w[topic kind language].freeze

  # not_found is a normal outcome: the sources had no answer, and the model said so
  enum :status, { pending: "pending", answering: "answering", answered: "answered",
                  not_found: "not_found", failed: "failed" }, validate: true

  # question.topic reads filters["topic"]: forms and params work with plain attributes
  store_accessor :filters, *FILTERS

  validates :text, presence: true, length: { maximum: 2_000 }

  normalizes :filters, with: ->(filters) { filters.to_h.stringify_keys.slice(*FILTERS).compact_blank }
  # store_accessor writes into the hash in place, which skips normalizes; reassign to apply it
  before_validation { self.filters = filters }

  def done? = answered? || not_found? || failed?

  # Replaces the answer block on every page subscribed to this question
  def broadcast_answer
    broadcast_replace_to self, target: ActionView::RecordIdentifier.dom_id(self, :answer),
                               partial: "questions/answer", locals: { question: self }
  end

  # Chunks in [S1..Sn] order; a re-indexed chunk is missing and yields nil
  def sources
    by_id = Chunk.includes(:document).where(id: chunk_ids).index_by(&:id)
    chunk_ids.map { by_id[_1] }
  end
end
