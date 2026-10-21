# How often the LLM judge agrees with a human on the same answers: exactly and within ±1.
# Runs AnswerGrader#evaluate on unsaved cards, so nothing is written except llm_calls.
class GraderEval
  Item = Data.define(:question, :reference_answer, :source, :answer, :human_score)
  Result = Data.define(:item, :judge_score, :feedback)

  def self.load(path)
    YAML.load_file(path).map do |row|
      Item.new(**row.slice(*Item.members.map(&:to_s)).symbolize_keys)
    end
  end

  def initialize(items)
    @items = items
  end

  def results
    @results ||= @items.map do |item|
      card = Card.new(prompt: item.question, reference_answer: item.reference_answer, chunk: Chunk.new(content: item.source))
      verdict = AnswerGrader.new(Attempt.new(card:, answer: item.answer)).evaluate
      Result.new(item:, judge_score: verdict.errors.empty? ? verdict.data["score"] : nil, feedback: verdict.data&.dig("feedback"))
    end
  end

  # Failed verdicts count as disagreement: a judge that cannot answer is not agreeing
  def summary
    diffs = results.map { _1.judge_score && (_1.judge_score - _1.item.human_score).abs }
    scored = diffs.compact
    {
      answers: results.size,
      exact: share(diffs.count(0)),
      within_one: share(diffs.count { _1 && _1 <= 1 }),
      mean_abs_error: scored.empty? ? nil : (scored.sum.to_f / scored.size).round(2),
      judge_failures: diffs.count(nil)
    }
  end

  def disagreements = results.reject { _1.judge_score == _1.item.human_score }

  private

  def share(count) = results.empty? ? nil : count.fdiv(results.size).round(2)
end
