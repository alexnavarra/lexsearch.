# Spend on LLM calls for a period, grouped by model and purpose (answer, cards, grade, eval_*).
# Cost comes from llm_calls.cost_usd, computed at call time; nil cost means a model without a price.
class LlmCostReport
  Row = Data.define(:model, :purpose, :calls, :errors, :input_tokens, :cache_write_tokens, :cache_read_tokens,
                    :output_tokens, :cost_usd, :unpriced) do
    # Share of the prompt served from the provider cache
    def cache_hit_rate
      prompt = input_tokens + cache_write_tokens + cache_read_tokens
      prompt.zero? ? 0.0 : cache_read_tokens.fdiv(prompt)
    end
  end

  SUMS = %i[input_tokens cache_write_tokens cache_read_tokens output_tokens].freeze

  def initialize(from:, to: Time.current)
    @range = from..to
  end

  def rows
    @rows ||= LlmCall.where(created_at: @range).group(:model, :purpose).order(:model, :purpose)
                     .pluck(:model, :purpose, *aggregates).map { Row.new(*_1) }
  end

  def total
    Row.new(model: "total", purpose: "", calls: rows.sum(&:calls), errors: rows.sum(&:errors),
            **SUMS.index_with { |sum| rows.sum(&sum) }, cost_usd: rows.sum(&:cost_usd), unpriced: rows.sum(&:unpriced))
  end

  def to_s
    header = "LLM calls #{@range.begin.to_date}..#{@range.end.to_date}"
    return "#{header}: none" if rows.empty?

    lines = [ *rows, total ].map do |row|
      [ row.model, row.purpose, row.calls, row.errors, *SUMS.map { row.public_send(_1) },
        "#{(row.cache_hit_rate * 100).round}%", format("$%.6f", row.cost_usd) + (row.unpriced.positive? ? " (+#{row.unpriced} unpriced)" : "") ]
    end
    table = [ %w[model purpose calls errors input cache_write cache_read output cache_hit cost], *lines ]
    widths = table.transpose.map { |column| column.map { _1.to_s.size }.max }
    [ header, *table.map { |row| row.zip(widths).map { |cell, width| cell.to_s.ljust(width) }.join("  ").rstrip } ].join("\n")
  end

  private

  def aggregates
    [ "COUNT(*)", "COUNT(*) FILTER (WHERE status = 'error')",
      *SUMS.map { "COALESCE(SUM(#{_1}), 0)" },
      "COALESCE(SUM(cost_usd), 0)", "COUNT(*) FILTER (WHERE status = 'ok' AND cost_usd IS NULL)" ].map { Arel.sql(_1) }
  end
end
