require "rails_helper"

RSpec.describe "Search", type: :request do
  before { stub_embeddings }

  let!(:chunk) do
    content = "VACUUM FULL rewrites the table <script>x</script>"
    create(:chunk, section_ref: "PG > Vacuum", content:,
                   embedding: EmbeddingsHelpers.vector_for("PG > Vacuum\n\n#{content}"), embedding_model: "bge-m3")
  end

  it "renders the form and one frame per method without searching itself" do
    get search_path(q: "vacuum", topic: "postgresql")

    expect(response.body).to include('id="results_vector"', 'id="results_fulltext"', 'id="results_hybrid"')
    expect(response.body).to include("q=vacuum").and include("topic=postgresql")
    expect(a_request(:post, %r{/api/embed})).not_to have_been_made
  end

  it "shows vector results with distances" do
    get search_results_path(mode: "vector", q: "vacuum full")

    expect(response.body).to include('id="results_vector"', "PG &gt; Vacuum", "distance")
  end

  it "shows full-text results with a highlighted, escaped snippet" do
    get search_results_path(mode: "fulltext", q: "vacuum full")

    expect(response.body).to include("rank", '<mark class="bg-yellow-200">VACUUM</mark>')
    expect(response.body).not_to include("<script>x")
    expect(a_request(:post, %r{/api/embed})).not_to have_been_made
  end

  it "shows hybrid results with RRF score and places in both lists" do
    get search_results_path(mode: "hybrid", q: "vacuum full", strategy: "sql")

    expect(response.body).to include("RRF 0.0328", "вектор #1 · слова #1")
  end

  it "shows an error inside the frame when embeddings are down" do
    stub_request(:post, %r{/api/embed}).to_timeout

    get search_results_path(mode: "hybrid", q: "vacuum")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Embeddings недоступны")
  end
end
