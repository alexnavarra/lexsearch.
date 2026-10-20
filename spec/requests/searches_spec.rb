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

  it "searches by keywords with a highlighted, escaped snippet" do
    create(:chunk, section_ref: "PG > Vacuum", content: "VACUUM FULL rewrites the table <script>x</script>")

    get search_path(q: "vacuum full", mode: "fulltext")

    expect(response.body).to include("PG &gt; Vacuum", "rank", '<mark class="bg-yellow-200">VACUUM</mark>')
    expect(response.body).not_to include("<script>x")
    expect(a_request(:post, %r{/api/embed})).not_to have_been_made
  end

  it "renders an error when embeddings are down" do
    stub_request(:post, %r{/api/embed}).to_timeout

    get search_path(q: "jsonb")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Embeddings недоступны")
  end
end
