# Semantic search: embeds the query and returns the nearest chunks by cosine distance.
# Each result has #neighbor_distance (0 = same direction, 2 = opposite).
class VectorSearch
  LIMIT = 10
  FILTERS = %i[topic language kind].freeze

  def initialize(query, filters: {}, limit: LIMIT)
    @query, @limit = query.to_s.strip, limit
    @filters = filters.to_h.symbolize_keys.slice(*FILTERS).compact_blank
  end

  def call
    return [] if @query.empty?

    vector = Embeddings.embed_query(@query)
    Chunk.transaction do
      # HNSW finds ~40 candidates, then WHERE filters them; with a narrow filter that leaves
      # fewer than LIMIT rows. Iterative scan keeps walking the index until LIMIT is reached.
      Chunk.connection.execute("SET LOCAL hnsw.iterative_scan = strict_order")
      scope.nearest_neighbors(:embedding, vector, distance: "cosine").limit(@limit).includes(:document).to_a
    end
  end

  private

  def scope
    chunks = Chunk.where(embedding_model: Embeddings.model)
    chunks = chunks.where(@filters.slice(:topic, :language))
    chunks = chunks.joins(:document).where(documents: { kind: @filters[:kind] }) if @filters[:kind]
    chunks
  end
end
