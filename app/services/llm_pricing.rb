# Cost of one LLM call from its token counts and config/llm_prices.yml.
# Four token kinds, four rates: cache reads are ~10x cheaper than input, cache writes ~25% dearer.
module LlmPricing
  PRICES = Rails.root.join("config/llm_prices.yml")
  KINDS = { input_tokens: "input", cache_write_tokens: "cache_write", cache_read_tokens: "cache_read", output_tokens: "output" }.freeze

  class << self
    # USD as BigDecimal, nil when the model has no price (the report shows it as unknown)
    def cost(model, **tokens)
      rates = rates_for(model, prompt_tokens(tokens)) or return
      KINDS.sum { |kind, rate| tokens[kind].to_i * BigDecimal(rates.fetch(rate).to_s) } / 1_000_000
    end

    def prices = @prices ||= YAML.safe_load_file(PRICES)

    attr_writer :prices

    private

    def rates_for(model, prompt)
      key = prices.keys.select { model.to_s.start_with?(_1) }.max_by(&:length) or return
      entry = prices[key]
      entry["long_after"] && prompt > entry["long_after"] ? entry["long"] : entry
    end

    # The whole prompt counts toward the long-context threshold, cached or not
    def prompt_tokens(tokens) = tokens.values_at(:input_tokens, :cache_write_tokens, :cache_read_tokens).sum(&:to_i)
  end
end
