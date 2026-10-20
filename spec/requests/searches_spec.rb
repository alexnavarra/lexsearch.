require "rails_helper"

RSpec.describe "Search", type: :request do
  before { stub_embeddings }

  it "shows the nearest chunks with distances" do
    create(:chunk, section_ref: "Guide > GIN", content: "gin jsonb",
                   embedding: EmbeddingsHelpers.vector_for("Guide > GIN\n\ngin jsonb"), embedding_model: "bge-m3")

    get search_path(q: "jsonb gin", topic: "")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Guide &gt; GIN", "distance")
  end

  it "renders an error when embeddings are down" do
    stub_request(:post, %r{/api/embed}).to_timeout

    get search_path(q: "jsonb")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Embeddings недоступны")
  end
end
