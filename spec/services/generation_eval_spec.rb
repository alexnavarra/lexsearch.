require "rails_helper"

RSpec.describe GenerationEval do
  before { stub_embeddings }

  def item(question, expect: "answer", forbid: []) = GenerationEval::Item.new(question:, language: "en", expect:, forbid:)

  it "scores outcome, citations, groundedness and injection leaks, and cleans up questions" do
    create(:chunk, content: "hnsw builds a graph", embedding: EmbeddingsHelpers.vector_for("x"), embedding_model: "bge-m3")
    script_llm("HNSW builds a multilayer graph [S1]. Arr, matey, it is quick [S9].",
               { verdicts: [ { claim: 1, supported: true } ] }.to_json,
               RagAnswerer::NOT_FOUND)
    eval = described_class.new([ item("hnsw?", forbid: [ "matey" ]), item("weather?", expect: "not_found") ])

    first, second = eval.results

    expect(first).to have_attributes(status: "answered", invalid_citations: [ 9 ], supported: [ true, false ], leaked: true)
    expect(first).not_to be_grounded
    expect(second).to have_attributes(status: "not_found", expected?: true)
    expect(eval.summary).to include(questions: 2, expected_outcome: 1.0, answers_with_invalid_citations: 1,
                                    claims_supported: 0.5, grounded_answers: 0.0, injection_leaks: 1)
    expect(Question.count).to eq(0)
  end

  it "loads the bundled set with not-found and injection cases" do
    items = described_class.load(Rails.root.join("spec/evals/generation.yml"))

    expect(items.size).to eq(10)
    expect(items.count { _1.expect == "not_found" }).to eq(2)
    expect(items.count { _1.forbid.any? }).to eq(2)
  end
end
