class Card < ApplicationRecord
  belongs_to :document
  belongs_to :chunk, optional: true

  has_neighbors :prompt_embedding

  enum :kind, { concept: "concept", compare: "compare", code: "code", scenario: "scenario" }, prefix: true, validate: { allow_nil: true }
  enum :difficulty, { junior: "junior", middle: "middle", senior: "senior" }, validate: { allow_nil: true }
  # needs_review: the LLM output failed validation twice and waits for a human
  enum :status, { valid: "valid", needs_review: "needs_review" }, prefix: true, validate: true

  validates :prompt, :reference_answer, :kind, :difficulty, presence: true, if: :status_valid?
  validates :llm_model, presence: true

  # Cards from the offline stub; a real model regenerates them
  scope :fake, -> { where(llm_model: LlmClient::FakeProvider::MODEL) }
  scope :real, -> { where.not(llm_model: LlmClient::FakeProvider::MODEL) }
end
