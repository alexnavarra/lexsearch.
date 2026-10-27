require "rails_helper"

RSpec.describe LlmCostReport do
  def call_log(**attributes)
    LlmCall.create!(provider: "anthropic", model: "claude-haiku-5-5", status: "ok", purpose: "answer", **attributes)
  end

  it "sums tokens and cost by model and purpose within the period" do
    call_log(purpose: "grade", input_tokens: 100, cache_read_tokens: 300, output_tokens: 50, cost_usd: 0.002)
    call_log(purpose: "grade", input_tokens: 100, cache_write_tokens: 300, output_tokens: 50, cost_usd: 0.003)
    call_log(status: "error")
    call_log(model: "mystery", input_tokens: 5)
    call_log(input_tokens: 999, created_at: 2.months.ago)

    report = described_class.new(from: 1.day.ago)
    grade = report.rows.find { _1.purpose == "grade" }

    expect(report.rows.map { [ _1.model, _1.purpose ] }).to eq([ %w[claude-haiku-5-5 answer], %w[claude-haiku-5-5 grade], %w[mystery answer] ])
    expect(grade).to have_attributes(calls: 2, input_tokens: 200, cache_write_tokens: 300, cache_read_tokens: 300, output_tokens: 100)
    expect(grade.cost_usd).to eq(BigDecimal("0.005"))
    expect(grade.cache_hit_rate).to eq(0.375)
    expect(report.total).to have_attributes(calls: 4, errors: 1, unpriced: 1, cost_usd: BigDecimal("0.005"))
    expect(report.to_s).to include("grade", "38%", "$0.005000 (+1 unpriced)")
  end

  it "says so when there were no calls" do
    expect(described_class.new(from: 1.day.ago).to_s).to end_with(": none")
  end
end
