# Semantic search: embeds the query and returns the nearest chunks by cosine distance.
# Each result has #neighbor_distance (0 = same direction, 2 = opposite).
class VectorSearch
  LIMIT = 10
  FILTERS = %i[topic language kind].freeze

  # HNSW finds ~40 candidates, then WHERE filters them; with a narrow filter that leaves
  # fewer than LIMIT rows. Iterative scan keeps walking the index until LIMIT is reached.
  def self.with_iterative_scan
    Chunk.transaction do
      Chunk.connection.execute("SET LOCAL hnsw.iterative_scan = strict_order")
      yield
    end
  end

  # Pass a precomputed `vector` to avoid embedding the same query twice
  def initialize(query, filters: {}, limit: LIMIT, vector: nil)
    @query, @limit, @vector = query.to_s.strip, limit, vector
    @filters = filters.to_h.symbolize_keys.slice(*FILTERS).compact_blank
  end

  def call
    return [] if @query.empty?

    self.class.with_iterative_scan { relation.includes(:document).to_a }
  end

  # Ordered, limited chunks with a neighbor_distance column; HybridSearch uses it as a subquery
  def relation
    vector = @vector || Embeddings.embed_query(@query)
    scope.nearest_neighbors(:embedding, vector, distance: "cosine").limit(@limit)
  end

  private

  def scope
    chunks = Chunk.where(embedding_model: Embeddings.model)
    chunks = chunks.where(@filters.slice(:topic, :language))
    chunks = chunks.joins(:document).where(documents: { kind: @filters[:kind] }) if @filters[:kind]
    chunks
  end
end
