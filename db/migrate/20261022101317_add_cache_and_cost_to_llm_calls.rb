class AddCacheAndCostToLlmCalls < ActiveRecord::Migration[8.1]
  def change
    # Prompt caching: tokens written to / read from the provider cache, billed at their own rates
    add_column :llm_calls, :cache_write_tokens, :integer
    add_column :llm_calls, :cache_read_tokens, :integer
    # Cost at the prices of the day of the call (config/llm_prices.yml); nil for unknown models
    add_column :llm_calls, :cost_usd, :decimal, precision: 12, scale: 6
  end
end
