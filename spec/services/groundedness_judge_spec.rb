require "rails_helper"

RSpec.describe GroundednessJudge do
  def verdicts(*pairs) = { verdicts: pairs.map { |claim, supported| { claim:, supported: } } }.to_json

  it "splits an answer into claims with their citations and skips short fragments" do
    claims = described_class.claims("HNSW builds a layered graph [S1]. IVFFlat splits vectors into lists [S2][S3].\n- [S1]\nIt is fast.")

    expect(claims.map(&:source_ids)).to eq([ [ 1 ], [ 2, 3 ] ])
  end

  it "asks about cited claims only and treats uncited ones as unsupported" do
    claims = described_class.claims("HNSW builds a layered graph [S1]. Uncited claim about indexes.")
    provider = script_llm(verdicts([ 1, true ]))

    expect(described_class.new(claims, { 1 => "HNSW creates a multilayer graph" }).call).to eq([ true, false ])

    content = provider.requests.first[:messages].first[:content]
    expect(content).to include(%(<source id="S1">), %(<claim n="1">), "multilayer graph")
    expect(content).not_to include("Uncited claim")
    expect(LlmCall.last.purpose).to eq("eval_grounded")
  end

  it "rejects verdicts for the wrong claims and retries" do
    claims = described_class.claims("HNSW builds a layered graph [S1]. IVFFlat splits vectors into lists [S1].")
    provider = script_llm(verdicts([ 1, true ]), verdicts([ 1, true ], [ 2, false ]))

    expect(described_class.new(claims, { 1 => "graph" }).call).to eq([ true, false ])
    expect(provider.requests.size).to eq(2)
  end

  it "returns nil when the judge stays invalid" do
    claims = described_class.claims("HNSW builds a layered graph [S1].")
    script_llm("nope", "still nope")

    expect(described_class.new(claims, { 1 => "graph" }).call).to be_nil
  end

  it "makes no call when nothing is cited" do
    provider = script_llm

    expect(described_class.new(described_class.claims("A claim without any citation."), { 1 => "x" }).call).to eq([ false ])
    expect(provider.requests).to be_empty
  end
end
