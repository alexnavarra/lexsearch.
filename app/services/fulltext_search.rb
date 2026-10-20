# Keyword search over chunks.tsv. The query language is unknown, so it is parsed by both
# the english and russian configs and OR-ed. Each result has #rank and #snippet.
class FulltextSearch
  LIMIT = 10
  FILTERS = %i[topic language kind].freeze
  # Private-use characters mark matches; the view escapes the snippet, then turns them into <mark>
  MARK_START, MARK_STOP = "", ""
  HEADLINE_OPTIONS = "StartSel=#{MARK_START}, StopSel=#{MARK_STOP}, MaxFragments=2, MinWords=10, MaxWords=30".freeze
  CONFIG = "CASE chunks.language WHEN 'russian' THEN 'russian'::regconfig ELSE 'english'::regconfig END".freeze

  def initialize(query, filters: {}, limit: LIMIT)
    @query, @limit = query.to_s.strip, limit
    @filters = filters.to_h.symbolize_keys.slice(*FILTERS).compact_blank
  end

  def call
    return [] if @query.empty? || stopwords_only?

    scope.where("chunks.tsv @@ #{tsquery}")
         .select("chunks.*", "ts_rank_cd(chunks.tsv, #{tsquery}) AS rank")
         .order("rank DESC", :id)
         .limit(@limit)
         .includes(:document)
         .to_a
         .tap { |chunks| add_snippets(chunks) }
  end

  private

  def tsquery
    @tsquery ||= Chunk.sanitize_sql_array(
      [ "(websearch_to_tsquery('english', :q) || websearch_to_tsquery('russian', :q))", q: @query ]
    )
  end

  # "the и" has no lexemes; matching against an empty tsquery only yields a NOTICE and nothing
  def stopwords_only?
    Chunk.connection.select_value("SELECT numnode(#{tsquery})").zero?
  end

  # ts_headline re-parses the whole text, so run it only for the rows we show
  def add_snippets(chunks)
    return if chunks.empty?

    snippets = Chunk.where(id: chunks.map(&:id)).pluck(
      :id, Arel.sql(Chunk.sanitize_sql_array([ "ts_headline(#{CONFIG}, content, #{tsquery}, ?)", HEADLINE_OPTIONS ]))
    ).to_h
    chunks.each { _1.snippet = snippets[_1.id] }
  end

  def scope
    chunks = Chunk.where(@filters.slice(:topic, :language))
    chunks = chunks.joins(:document).where(documents: { kind: @filters[:kind] }) if @filters[:kind]
    chunks
  end
end
