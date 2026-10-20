require "rails_helper"

RSpec.describe GenerateCardsJob do
  include ActiveJob::TestHelper

  let(:chunk) { create(:chunk) }

  before { stub_embeddings }

  it "re-enqueues itself on rate limits and server errors" do
    script_llm(LlmClient::RetryableError.new("429"))

    expect { described_class.perform_now(chunk) }.to have_enqueued_job(described_class).with(chunk)
    expect(Card.count).to eq(0)
  end

  it "replaces stub cards when a real model is configured" do
    create(:card, chunk:, document: chunk.document, llm_model: "fake")
    script_llm({ cards: [ { prompt: "Real?", reference_answer: "Yes.", kind: "concept", difficulty: "junior" } ] }.to_json)

    described_class.perform_now(chunk)

    expect(Card.all.map { [ _1.chunk_id, _1.prompt, _1.llm_model ] }).to eq([ [ chunk.id, "Real?", "scripted" ] ])
  end

  it "skips chunks that already have cards" do
    create(:card, chunk:, document: chunk.document)
    provider = script_llm

    described_class.perform_now(chunk)

    expect(provider.requests).to be_empty
  end
end
