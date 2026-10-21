require "rails_helper"

RSpec.describe GraderEval do
  def item(answer, human_score)
    GraderEval::Item.new(question: "When to use GIN?", reference_answer: "For jsonb and arrays.",
                         source: "GIN is an inverted index for arrays and jsonb.", answer:, human_score:)
  end

  def verdict(score) = { covered: [], missed: [], incorrect: [], feedback: "f#{score}", score: }.to_json

  it "measures exact and ±1 agreement without saving anything" do
    script_llm(verdict(5), verdict(2), "bad", "bad")
    eval = described_class.new([ item("jsonb and arrays", 5), item("arrays", 4), item("", 0), item("btree", 1) ])

    expect(eval.summary).to eq(answers: 4, exact: 0.5, within_one: 0.5, mean_abs_error: 0.67, judge_failures: 1)
    expect(eval.disagreements.map(&:judge_score)).to eq([ 2, nil ])
    expect(Card.count + Attempt.count).to eq(0)
  end

  it "loads the bundled set: 20 answers with human scores" do
    items = described_class.load(Rails.root.join("spec/evals/grader.yml"))

    expect(items.size).to eq(20)
    expect(items.map(&:human_score)).to all(be_between(0, 5))
  end
end
