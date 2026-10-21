# Keyword search over chunks.tsv. The query language is unknown, so it is parsed by both
# the english and russian configs and OR-ed. Each result has #rank and #snippet.
class FulltextSearch
  LIMIT = 10
  FILTERS = %i[topic language kind].freeze
  # Private-use characters mark matches; the view escapes the snippet, then turns them into <mark>
  MARK_START, MARK_STOP = "", ""
  HEADLINE_OPTIONS = "StartSel=#{MARK_START}, StopSel=#{MARK_STOP}, MaxFragments=2, MinWords=10, MaxWords=30".freeze
  CONFIG = "CASE chunks.language WHEN 'russian' THEN 'russian'::regconfig ELSE 'english'::regconfig END".freeze

  # match: :all requires every word (websearch AND); :any needs one word and lets the rank sort it out,
  # which suits natural-language questions. Queries with "-word" or "quotes" always use :all.
  def initialize(query, filters: {}, limit: LIMIT, match: :all)
    @query, @limit = query.to_s.strip, limit
    @match = @query.match?(/["-]/) ? :all : match.to_sym
    @filters = filters.to_h.symbolize_keys.slice(*FILTERS).compact_blank
  end

  def call
    return [] if @query.empty? || stopwords_only?

    relation.includes(:document).to_a.tap { |chunks| add_snippets(chunks) }
  end

  # Ordered, limited chunks with a rank column; HybridSearch uses it as a subquery
  def relation
    return Chunk.where("FALSE") if @query.empty? || stopwords_only?

    rank = "ts_rank_cd(chunks.tsv, #{tsquery})"
    # Order by the expression, not the alias: the relation stays valid if its select list is replaced
    scope.where("chunks.tsv @@ #{tsquery}")
         .select("chunks.*", "#{rank} AS rank")
         .order(Arel.sql("#{rank} DESC"), :id)
         .limit(@limit)
  end

  private

  def tsquery
    @tsquery ||= Chunk.sanitize_sql_array([ "(#{parse('english')} || #{parse('russian')})", q: @query ])
  end

  # "a & b" -> "a | b" on the parsed tsquery text; phrases (<->) are left intact
  def parse(config)
    parsed = "websearch_to_tsquery('#{config}', :q)"
    @match == :any ? "replace(#{parsed}::text, '&', '|')::tsquery" : parsed
  end

  # "the и" has no lexemes; matching against an empty tsquery only yields a NOTICE and nothing
  def stopwords_only?
    return @stopwords_only if defined?(@stopwords_only)

    @stopwords_only = Chunk.connection.select_value("SELECT numnode(#{tsquery})").zero?
  end

  # ts_headline re-parses the whole text, so run it only for the rows we show
  def add_snippets(chunks)
    return if chunks.empty?

    # tsquery already holds the user's text: sanitizing it again would treat "?" or ":word" in it as binds
    headline = "ts_headline(#{CONFIG}, content, #{tsquery}, #{Chunk.connection.quote(HEADLINE_OPTIONS)})"
    snippets = Chunk.where(id: chunks.map(&:id)).pluck(:id, Arel.sql(headline)).to_h
    chunks.each { _1.snippet = snippets[_1.id] }
  end

  def scope
    chunks = Chunk.where(@filters.slice(:topic, :language))
    chunks = chunks.joins(:document).where(documents: { kind: @filters[:kind] }) if @filters[:kind]
    chunks
  end
end
