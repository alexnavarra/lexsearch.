require "rails_helper"

RSpec.describe LlmPricing do
  it "prices each token kind at its own rate" do
    cost = described_class.cost("claude-sonnet-5-5", input_tokens: 1_000_000, cache_write_tokens: 1_000_000,
                                                     cache_read_tokens: 1_000_000, output_tokens: 1_000_000)

    expect(cost).to eq(2 + 2.5 + 0.1 + 10)
  end

  it "matches dated model ids and returns nil for unknown models" do
    expect(described_class.cost("claude-haiku-5-5-20260901", output_tokens: 2_000_000)).to eq(1)
    expect(described_class.cost("mystery-model", output_tokens: 10)).to be_nil
  end

  it "switches to long-context rates when the whole prompt, cached part included, is over the threshold" do
    short = described_class.cost("claude-haiku-5-5", input_tokens: 50_000, cache_read_tokens: 50_000)
    long = described_class.cost("claude-haiku-5-5", input_tokens: 50_000, cache_read_tokens: 50_001)

    expect(short).to eq(BigDecimal("0.0055"))
    expect(long).to be > short * 4
  end
end
