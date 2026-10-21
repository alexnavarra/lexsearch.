require "rails_helper"

RSpec.describe "Exam", type: :request do
  it "shows overdue cards before new ones and skips future and review cards" do
    create(:card, prompt: "New card?")
    create(:card, prompt: "Overdue card?", due_at: 2.days.ago)
    create(:card, prompt: "Future card?", due_at: 3.days.from_now)
    create(:card, prompt: "Broken card?", status: "needs_review")

    get exam_path

    expect(response.body).to include("Overdue card?").and(include("К повторению сегодня"))
    expect(response.body).not_to include("New card?", "Future card?", "Broken card?")
  end

  it "filters by topic and skips cards that are being graded" do
    rails = create(:card, prompt: "Rails card?", document: create(:document, topic: "rails"))
    create(:card, prompt: "PG card?")
    rails.attempts.create!(answer: "x")
    create(:card, prompt: "Second rails card?", document: create(:document, topic: "rails"))

    get exam_path(topic: "rails")

    expect(response.body).to include("Second rails card?")
    expect(response.body).not_to include("PG card?", "Rails card?")
  end

  it "says when nothing is due" do
    create(:card, due_at: 1.day.from_now)

    get exam_path

    expect(response.body).to include("На сегодня всё")
  end

  it "creates an attempt, queues grading and keeps the topic" do
    card = create(:card)

    expect {
      post card_attempts_path(card), params: { attempt: { answer: "for jsonb" }, topic: "postgresql" }
    }.to have_enqueued_job(GradeAttemptJob)

    expect(card.attempts.last.answer).to eq("for jsonb")
    expect(response).to redirect_to(attempt_path(card.attempts.last, topic: "postgresql"))
  end

  it "treats «Не помню» as a blank answer" do
    card = create(:card)

    post card_attempts_path(card), params: { attempt: { answer: "half-typed" }, skip: "Не помню" }

    expect(card.attempts.last.answer).to eq("")
  end

  it "shows a pending attempt with a stream subscription" do
    attempt = create(:card).attempts.create!(answer: "x")

    get attempt_path(attempt)

    expect(response.body).to include("turbo-cable-stream-source", "Судья проверяет")
  end

  it "shows the verdict, the reference, the source link and average scores" do
    card = create(:card)
    card.schedule!(2)
    card.attempts.create!(answer: "B-tree", status: "graded", score: 2, llm_model: "claude-haiku-5-5",
                          verdict: { "covered" => [], "missed" => [ "jsonb" ], "incorrect" => [ "GIN is a <b>B-tree</b>" ], "feedback" => "No." })

    get attempt_path(card.attempts.last)

    expect(response.body).to include("2 / 5", "Пропущено", "jsonb", "GIN is a &lt;b&gt;B-tree", card.reference_answer,
                                     "#chunk_#{card.chunk_id}", "через 1 дн.")

    get exam_path
    expect(response.body).to include("Средний балл по темам", "2.0 / 5")
  end
end
