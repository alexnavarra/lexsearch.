# One exam answer to a card and the judge's verdict on it
class Attempt < ApplicationRecord
  belongs_to :card

  enum :status, { pending: "pending", grading: "grading", graded: "graded", failed: "failed" }, validate: true

  # Blank is allowed: "I don't remember" is an answer worth 0
  validates :answer, length: { maximum: 5_000 }
  validates :score, inclusion: { in: 0..5 }, if: :graded?

  normalizes :answer, with: ->(answer) { answer.to_s.strip }

  scope :in_progress, -> { where(status: %w[pending grading]) }

  def done? = graded? || failed?

  %w[covered missed incorrect].each { |key| define_method(key) { Array(verdict[key]) } }

  def feedback = verdict["feedback"]

  # Replaces the verdict block on every page subscribed to this attempt
  def broadcast_verdict
    broadcast_replace_to self, target: ActionView::RecordIdentifier.dom_id(self, :verdict),
                               partial: "attempts/verdict", locals: { attempt: self }
  end
end
