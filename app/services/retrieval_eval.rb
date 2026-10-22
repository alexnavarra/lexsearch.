# Measures search quality on a labeled set: for each question, the place of the first relevant
# chunk in the top LIMIT of each mode, then recall@k (share of questions with a hit in the top k)
# and MRR (mean of 1 / place, 0 for a miss).
class RetrievalEval
  # *_any: full-text search with OR instead of AND
  MODES = %i[vector fulltext fulltext_any hybrid hybrid_any].freeze
  KS = [ 1, 5, 10 ].freeze
  LIMIT = KS.max

  # expected: section_refs (a hit is equal to one or under it); chunk_id: exact chunk (synthetic set)
  Item = Data.define(:question, :language, :expected, :chunk_id) do
    def relevant?(chunk)
      return chunk.id == chunk_id if chunk_id

      expected.any? { chunk.section_ref == _1 || chunk.section_ref.start_with?("#{_1} > ") }
    end

    # False when none of the expected sections exist: the document is not loaded (a private book) or the label has a typo
    def answerable?
      return Chunk.exists?(chunk_id) if chunk_id

      expected.any? do |ref|
        Chunk.where("section_ref = :ref OR section_ref LIKE :under", ref:, under: "#{Chunk.sanitize_sql_like(ref)} > %").exists?
      end
    end
  end

  Metrics = Data.define(:count, :recall, :mrr)

  def self.load(path)
    YAML.load_file(path).map do |row|
      Item.new(question: row.fetch("question"), language: row.fetch("language"), expected: Array(row["expected"]), chunk_id: nil)
    end
  end

  # Card questions with the chunk they were made from: a free but biased set (the wording follows the chunk)
  def self.from_cards(cards = Card.real.status_valid.where.not(chunk_id: nil))
    cards.includes(:chunk).map do |card|
      Item.new(question: card.prompt, language: card.chunk.language == "russian" ? "ru" : "en", expected: [], chunk_id: card.chunk_id)
    end
  end

  # places: [Integer or nil] per question
  def self.metrics(places)
    count = places.size
    recall = KS.to_h { |k| [ k, count.zero? ? 0.0 : places.count { _1 && _1 <= k }.fdiv(count) ] }
    mrr = count.zero? ? 0.0 : places.sum { _1 ? 1.0 / _1 : 0 } / count
    Metrics.new(count:, recall:, mrr:)
  end

  attr_reader :items

  def initialize(items, filters: {})
    @items, @filters = items, filters
  end

  # { mode => [place or nil per item] }
  def places
    @places ||= begin
      results = @items.map { |item| search(item.question) }
      MODES.to_h { |mode| [ mode, @items.zip(results).map { |item, by_mode| place(item, by_mode[mode]) } ] }
    end
  end

  # { [mode, language] => Metrics }, language "all" plus each language in the set
  def report
    languages = [ "all", *@items.map(&:language).uniq.sort ]
    MODES.product(languages).to_h do |mode, language|
      selected = places[mode].select.with_index { |_, i| language == "all" || @items[i].language == language }
      [ [ mode, language ], self.class.metrics(selected) ]
    end
  end

  private

  def search(question)
    vector = Embeddings.embed_query(question)
    {
      vector: VectorSearch.new(question, filters: @filters, limit: LIMIT, vector:).call,
      fulltext: FulltextSearch.new(question, filters: @filters, limit: LIMIT).call,
      fulltext_any: FulltextSearch.new(question, filters: @filters, limit: LIMIT, match: :any).call,
      hybrid: HybridSearch.new(question, filters: @filters, limit: LIMIT, vector:).call.map(&:chunk),
      hybrid_any: HybridSearch.new(question, filters: @filters, limit: LIMIT, vector:, fulltext_match: :any).call.map(&:chunk)
    }
  end

  def place(item, chunks)
    index = chunks.index { item.relevant?(_1) }
    index && index + 1
  end
end
