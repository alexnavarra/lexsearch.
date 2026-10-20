# Hybrid search: runs vector and full-text search, then fuses the two rankings with
# Reciprocal Rank Fusion: score = Σ 1 / (K + place). Only places matter, so cosine
# distance and ts_rank_cd never have to be put on one scale.
# Two equivalent strategies: :ruby fuses in Ruby, :sql does it in one query (two CTEs).
class HybridSearch
  K = 60
  LIMIT = 10
  CANDIDATES = 40

  # vector_rank / fulltext_rank: 1-based place in each list, nil if the method missed the chunk
  Result = Data.define(:chunk, :score, :vector_rank, :fulltext_rank)

  def initialize(query, filters: {}, limit: LIMIT, candidates: CANDIDATES, strategy: :ruby)
    @query, @filters, @limit, @candidates, @strategy = query.to_s.strip, filters, limit, candidates, strategy.to_sym
  end

  def call
    return [] if @query.empty?

    vector = VectorSearch.new(@query, filters: @filters, limit: @candidates, vector: Embeddings.embed_query(@query))
    fulltext = FulltextSearch.new(@query, filters: @filters, limit: @candidates)
    rows = VectorSearch.with_iterative_scan { @strategy == :sql ? fuse_sql(vector, fulltext) : fuse_ruby(vector, fulltext) }
    load_chunks(rows)
  end

  private

  # rows: [[id, score, vector_rank, fulltext_rank], ...] best first
  def fuse_ruby(vector, fulltext)
    ranks = Hash.new { |hash, id| hash[id] = {} }
    # Ties broken by id, exactly as ROW_NUMBER() does in fuse_sql
    vector_ids = Chunk.from(vector.relation, :chunks).pluck(:id, :neighbor_distance).sort_by { |id, distance| [ distance, id ] }
    fulltext_ids = Chunk.from(fulltext.relation, :chunks).pluck(:id, :rank).sort_by { |id, rank| [ -rank, id ] }
    vector_ids.each.with_index(1) { |(id, _), place| ranks[id][:vector] = place }
    fulltext_ids.each.with_index(1) { |(id, _), place| ranks[id][:fulltext] = place }

    ranks.map { |id, places| [ id, places.values.sum { 1.0 / (K + _1) }, places[:vector], places[:fulltext] ] }
         .sort_by { |id, score, _, _| [ -score, id ] }
         .first(@limit)
  end

  def fuse_sql(vector, fulltext)
    Chunk.connection.select_rows(<<~SQL)
      WITH vector AS (
        SELECT id, ROW_NUMBER() OVER (ORDER BY neighbor_distance, id) AS place FROM (#{vector.relation.to_sql}) v
      ), fulltext AS (
        SELECT id, ROW_NUMBER() OVER (ORDER BY rank DESC, id) AS place FROM (#{fulltext.relation.to_sql}) f
      )
      SELECT COALESCE(vector.id, fulltext.id) AS id,
             COALESCE(1.0::float8 / (#{K} + vector.place), 0) + COALESCE(1.0::float8 / (#{K} + fulltext.place), 0) AS score,
             vector.place, fulltext.place
      FROM vector FULL OUTER JOIN fulltext ON vector.id = fulltext.id
      ORDER BY score DESC, id
      LIMIT #{Integer(@limit)}
    SQL
  end

  def load_chunks(rows)
    chunks = Chunk.includes(:document).where(id: rows.map(&:first)).index_by(&:id)
    rows.map do |id, score, vector_rank, fulltext_rank|
      Result.new(chunk: chunks.fetch(id), score:, vector_rank:, fulltext_rank:)
    end
  end
end
