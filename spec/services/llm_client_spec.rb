require "rails_helper"

RSpec.describe LlmClient do
  def call = described_class.call(purpose: "test", system: "s", messages: [ { role: "user", content: "hi" } ])

  it "logs successful calls with tokens and duration" do
    script_llm("answer")

    expect(call.text).to eq("answer")
    expect(LlmCall.last).to have_attributes(purpose: "test", provider: "scripted", status: "ok",
                                            input_tokens: 10, output_tokens: 5, stop_reason: "end_turn")
    expect(LlmCall.last.duration_ms).to be >= 0
  end

  it "logs cache tokens and the cost, and passes the cache flag to the provider" do
    provider = script_llm("answer")
    allow(provider).to receive(:model).and_return("claude-haiku-5-5")
    allow(provider).to receive(:complete).and_wrap_original do |original, **request|
      original.call(**request).with(cache_write_tokens: 700, cache_read_tokens: 0)
    end

    described_class.call(purpose: "grade", system: "s", messages: [ { role: "user", content: "hi" } ], cache: true)

    expect(provider.requests.first[:cache]).to be(true)
    expect(LlmCall.last).to have_attributes(model: "claude-haiku-5-5", cache_write_tokens: 700, cache_read_tokens: 0,
                                            cost_usd: BigDecimal("0.000091")) # (10 * 0.10 + 700 * 0.125 + 5 * 0.50) per MTok
  end

  it "logs failed calls and re-raises" do
    script_llm(LlmClient::RetryableError.new("429"))

    expect { call }.to raise_error(LlmClient::RetryableError)
    expect(LlmCall.last).to have_attributes(status: "error", error: "LlmClient::RetryableError: 429")
  end

  it "picks the fake provider without an API key" do
    described_class.provider = nil
    stub_const("ENV", ENV.to_h.merge("ANTHROPIC_API_KEY" => "", "LLM_PROVIDER" => ""))
    expect(described_class.provider).to be_a(LlmClient::FakeProvider)

    described_class.provider = nil
    stub_const("ENV", ENV.to_h.merge("ANTHROPIC_API_KEY" => "sk-test", "LLM_PROVIDER" => ""))
    expect(described_class.provider).to be_a(LlmClient::AnthropicProvider)
  end

  describe LlmClient::Response do
    def response(text, stop_reason: "end_turn") = described_class.new(text:, stop_reason:, input_tokens: 0, output_tokens: 0)

    it "parses JSON and rejects broken, refused or truncated output" do
      expect(response('{"a":1}').json).to eq("a" => 1)
      expect { response("{oops").json }.to raise_error(LlmClient::InvalidOutput, /invalid JSON/)
      expect { response("{}", stop_reason: "refusal").json }.to raise_error(LlmClient::InvalidOutput, /refusal/)
      expect { response('{"a":', stop_reason: "max_tokens").json }.to raise_error(LlmClient::InvalidOutput, /max_tokens/)
    end
  end
end
