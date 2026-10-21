class AttemptsController < ApplicationController
  def create
    card = Card.status_valid.find(params[:card_id])
    # "Не помню" submits a blank answer: graded 0 without the judge
    answer = params[:skip] ? "" : params.dig(:attempt, :answer)
    attempt = card.attempts.create!(answer:)
    GradeAttemptJob.perform_later(attempt)
    redirect_to attempt_path(attempt, topic: params[:topic].presence)
  end

  def show
    @attempt = Attempt.includes(card: [ :document, :chunk ]).find(params[:id])
    @topic = params[:topic].presence
  end
end
