require "rails_helper"

RSpec.describe EmbedChunksJob do
  let(:document) { create(:document) }

  before { stub_embeddings }

  it "embeds chunks with breadcrumbs and records the model" do
    chunk = create(:chunk, document:, section_ref: "PG > GIN", content: "jsonb")

    described_class.perform_now(document)

    expect(chunk.reload).to have_attributes(embedding_model: "bge-m3")
    expect(chunk.embedding).to eq(EmbeddingsHelpers.vector_for("PG > GIN\n\njsonb"))
  end

  it "skips chunks already embedded by the current model and redoes other models" do
    create(:chunk, document:, embedding: EmbeddingsHelpers.vector_for("x"), embedding_model: "bge-m3")
    stale = create(:chunk, document:, embedding: EmbeddingsHelpers.vector_for("x"), embedding_model: "old-model")

    described_class.perform_now(document)

    expect(a_request(:post, %r{/api/embed}).with(body: hash_including(input: [ stale.embedding_text ]))).to have_been_made.once
    expect(stale.reload.embedding_model).to eq("bge-m3")
  end

  it "sends chunks in batches" do
    create_list(:chunk, 3, document:)
    stub_const("EmbedChunksJob::BATCH_SIZE", 2)

    described_class.perform_now(document)

    expect(a_request(:post, %r{/api/embed})).to have_been_made.twice
  end
end
