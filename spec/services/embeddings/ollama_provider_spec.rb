require "rails_helper"

RSpec.describe Embeddings::OllamaProvider do
  let(:url) { "http://ollama.test" }

  def provider(model: "bge-m3", dimensions: 3) = described_class.new(model:, dimensions:, url:)

  def stub_ollama(embeddings, status: 200)
    stub_request(:post, "#{url}/api/embed")
      .to_return(status:, headers: { "Content-Type" => "application/json" }, body: { embeddings: }.to_json)
  end

  it "embeds a batch of documents in one request" do
    stub_ollama([ [ 1, 0, 0 ], [ 0, 1, 0 ] ])

    expect(provider.embed_documents(%w[a b])).to eq([ [ 1, 0, 0 ], [ 0, 1, 0 ] ])
    expect(a_request(:post, "#{url}/api/embed").with(body: { model: "bge-m3", input: %w[a b] })).to have_been_made.once
  end

  it "adds task prefixes for models that need them" do
    stub_ollama([ [ 1, 0, 0 ] ])
    nomic = provider(model: "nomic-embed-text:latest")

    nomic.embed_query("q")
    nomic.embed_documents([ "d" ])

    expect(a_request(:post, "#{url}/api/embed").with(body: hash_including(input: [ "search_query: q" ]))).to have_been_made
    expect(a_request(:post, "#{url}/api/embed").with(body: hash_including(input: [ "search_document: d" ]))).to have_been_made
  end

  it "skips the request for an empty batch" do
    expect(provider.embed_documents([])).to eq([])
  end

  it "rejects vectors of the wrong size" do
    stub_ollama([ [ 1, 0 ] ])

    expect { provider.embed_query("q") }.to raise_error(Embeddings::Error, /expected 3/)
  end

  it "wraps HTTP errors" do
    stub_ollama([], status: 404)

    expect { provider.embed_query("q") }.to raise_error(Embeddings::Error, /bge-m3/)
  end
end
