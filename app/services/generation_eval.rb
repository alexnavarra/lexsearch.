# Runs RAG on a labeled set and checks the answers: was "not found" right, are the citations real,
# is every claim supported by the source it cites (GroundednessJudge), did injected instructions leak.
class GenerationEval
  # expect: "answer" or "not_found"; forbid: words that must not appear (prompt-injection canaries)
  Item = Data.define(:question, :language, :expect, :forbid)

  Result = Data.define(:item, :status, :answer, :invalid_citations, :claims, :supported, :leaked) do
    def expected? = (status == "not_found") == (item.expect == "not_found")
    def judged? = !supported.nil?
    def grounded? = judged? && claims.any? && supported.all?
  end

  def self.load(path)
    YAML.load_file(path).map do |row|
      Item.new(question: row.fetch("question"), language: row.fetch("language"),
               expect: row.fetch("expect", "answer"), forbid: Array(row["forbid"]))
    end
  end

  def initialize(items)
    @items = items
  end

  def results
    @results ||= @items.map { evaluate(_1) }
  end

  # Shares over the set; grounded counts only answers that should be answered and were
  def summary
    answered = results.select { _1.status == "answered" }
    judged = answered.select(&:judged?)
    claims = judged.sum { _1.claims.size }
    {
      questions: results.size,
      expected_outcome: share(results.count(&:expected?), results.size),
      answers_with_invalid_citations: answered.count { _1.invalid_citations.any? },
      claims_supported: share(judged.sum { _1.supported.count(true) }, claims),
      grounded_answers: share(judged.count(&:grounded?), judged.size),
      judge_failures: answered.size - judged.size,
      injection_leaks: results.count(&:leaked)
    }
  end

  private

  def evaluate(item)
    question = Question.create!(text: item.question)
    RagAnswerer.new(question).call
    sources = question.sources.each.with_index(1).to_h { |chunk, id| [ id, chunk&.content.to_s ] }
    claims = GroundednessJudge.claims(question.answer)
    supported = question.answered? ? GroundednessJudge.new(claims, sources).call : []

    Result.new(item:, status: question.status, answer: question.answer, invalid_citations: question.citations["invalid"],
               claims:, supported:, leaked: item.forbid.any? { question.answer.downcase.include?(_1.downcase) })
  ensure
    question&.destroy # eval runs should not clutter /questions; llm_calls keep the cost
  end

  def share(part, total) = total.zero? ? nil : part.fdiv(total).round(2)
end
