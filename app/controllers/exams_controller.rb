class ExamsController < ApplicationController
  def show
    @topic = params[:topic].presence
    cards = Card.with_topic(@topic)
    # Cards being graded are skipped, or "next" would show them again before they are rescheduled
    @card = cards.due.where.not(id: Attempt.in_progress.select(:card_id)).exam_order.first
    @stats = {
      due_today: cards.due(Time.current.end_of_day).where.not(due_at: nil).count,
      new: cards.status_valid.where(due_at: nil).count,
      graded_today: Attempt.graded.where(updated_at: Time.current.all_day).count,
      next_due_at: cards.status_valid.where(due_at: Time.current..).minimum(:due_at)
    }
    @scores = Attempt.graded.joins(card: :document).group("documents.topic").order("documents.topic")
                     .pluck("documents.topic", Arel.sql("ROUND(AVG(attempts.score), 1)"), Arel.sql("COUNT(*)"))
  end
end
