class Card < ApplicationRecord
  belongs_to :document
  belongs_to :chunk, optional: true
  has_many :attempts, -> { order(:id) }, inverse_of: :card

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

  # Exam queue: overdue reviews first, then never-shown cards
  scope :due, ->(now = Time.current) { status_valid.where(due_at: ..now).or(status_valid.where(due_at: nil)) }
  scope :exam_order, -> { order(Arel.sql("cards.due_at ASC NULLS LAST, cards.id")) }
  scope :with_topic, ->(topic) { topic.present? ? joins(:document).where(documents: { topic: }) : all }

  def scheduling = Scheduler::State.new(ease:, interval_days:, repetitions:)

  def schedule!(score, now: Time.current)
    state = Scheduler.call(scheduling, score)
    update!(**state.to_h, due_at: now + state.interval_days.days)
  end
end
