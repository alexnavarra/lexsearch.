require "rails_helper"

RSpec.describe VectorSearch do
  before { stub_embeddings }

  def embedded_chunk(content, model: "bge-m3", **attributes)
    create(:chunk, content:, section_ref: "S", embedding: EmbeddingsHelpers.vector_for(content), embedding_model: model, **attributes)
  end

  it "orders chunks by cosine distance to the query" do
    gin = embedded_chunk("gin index jsonb")
    btree = embedded_chunk("btree index range")
    embedded_chunk("borscht recipe beet")

    results = described_class.new("jsonb gin").call

    expect(results.first(2)).to eq([ gin, btree ])
    expect(results.map(&:neighbor_distance)).to eq(results.map(&:neighbor_distance).sort)
  end

  it "applies topic, language and kind filters" do
    rails_doc = create(:document, topic: "rails", kind: "notes")
    match = embedded_chunk("index", document: rails_doc)
    embedded_chunk("index", topic: "postgresql")

    expect(described_class.new("index", filters: { topic: "rails", kind: "notes", language: "" }).call).to eq([ match ])
    expect(described_class.new("index", filters: { kind: "book" }).call).to be_empty
  end

  it "ignores chunks embedded by another model" do
    embedded_chunk("index", model: "nomic-embed-text")

    expect(described_class.new("index").call).to be_empty
  end

  it "returns nothing for a blank query without calling the provider" do
    expect(described_class.new("  ").call).to eq([])
    expect(a_request(:post, %r{/api/embed})).not_to have_been_made
  end
end
