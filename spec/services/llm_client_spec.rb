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
