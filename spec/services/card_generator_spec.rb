require "rails_helper"

RSpec.describe CardGenerator do
  let(:chunk) { create(:chunk, section_ref: "PG > GIN", content: "GIN indexes speed up jsonb containment queries.") }

  before { stub_embeddings }

  def card(prompt = "When to use GIN?", **overrides)
    { prompt:, reference_answer: "For jsonb containment.", kind: "concept", difficulty: "middle" }.merge(overrides)
  end

  def cards_json(*cards) = { cards: }.to_json

  it "creates valid cards with prompt embeddings" do
    script_llm(cards_json(card))

    created = described_class.new(chunk).call

    expect(created.size).to eq(1)
    expect(created.first).to have_attributes(status: "valid", prompt: "When to use GIN?", kind: "concept",
                                             chunk:, document: chunk.document, embedding_model: "bge-m3")
    expect(created.first.prompt_embedding).to be_present
  end

  it "wraps the chunk in <source> tags and asks for structured output" do
    provider = script_llm(cards_json(card))

    described_class.new(chunk).call

    request = provider.requests.first
    expect(request[:messages].first[:content]).to include('<source section="PG &gt; GIN">', "GIN indexes speed up", "</source>")
    expect(request[:schema]).to eq(described_class::SCHEMA)
    expect(LlmCall.last.purpose).to eq("cards")
  end

  it "creates nothing for an empty array" do
    script_llm(cards_json)

    expect(described_class.new(chunk).call).to eq([])
    expect(Card.count).to eq(0)
  end

  it "retries invalid output once with the errors, then saves needs_review" do
    invalid = cards_json(card(kind: "trivia"), card("Second?"), card("Third?"), card("Fourth?"))
    provider = script_llm(invalid, invalid)

    created = described_class.new(chunk).call

    expect(provider.requests.size).to eq(2)
    retry_messages = provider.requests.last[:messages]
    expect(retry_messages.map { _1[:role] }).to eq(%w[user assistant user])
    expect(retry_messages.last[:content]).to include("invalid")
    expect(created.map(&:status).uniq).to eq([ "needs_review" ])
    expect(created.first.kind).to be_nil # unknown enum value dropped, error kept
    expect(created.first.validation_errors["errors"]).to be_present
    expect(created.first.validation_errors["raw"]).to eq(invalid)
  end

  it "accepts the corrected answer after a retry" do
    script_llm("not json", cards_json(card))

    expect(described_class.new(chunk).call.map(&:status)).to eq([ "valid" ])
  end

  it "keeps a needs_review trace when nothing is usable" do
    script_llm("not json", "still not json")

    created = described_class.new(chunk).call

    expect(created.size).to eq(1)
    expect(created.first).to have_attributes(status: "needs_review", prompt: nil)
    expect(created.first.validation_errors["errors"].first).to include("invalid JSON")
  end

  it "drops a question that duplicates an existing card" do
    script_llm(cards_json(card("When to use GIN?")), cards_json(card("When to use GIN?"), card("What is jsonb containment?")))

    described_class.new(chunk).call
    second = described_class.new(create(:chunk)).call

    expect(second.map(&:prompt)).to eq([ "What is jsonb containment?" ])
    expect(Card.count).to eq(2)
  end
end
