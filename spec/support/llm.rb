# LLM providers for tests: never the real API. ScriptedProvider replays canned texts in order.
class ScriptedProvider
  attr_reader :requests

  def initialize(*texts)
    @texts, @requests = texts, []
  end

  def name = "scripted"
  def model = "scripted"

  def complete(**request)
    @requests << request
    item = @texts.shift or raise "ScriptedProvider: no response left"
    raise item if item.is_a?(Exception) || (item.is_a?(Class) && item <= Exception)

    LlmClient::Response.new(text: item, stop_reason: "end_turn", input_tokens: 10, output_tokens: 5)
  end
end

module LlmHelpers
  def script_llm(*texts) = ScriptedProvider.new(*texts).tap { LlmClient.provider = _1 }

  def stub_anthropic(status: 200, body: nil, text: "{}", stop_reason: "end_turn")
    body ||= { id: "msg_1", type: "message", role: "assistant", model: "claude-haiku-5-5",
               content: [ { type: "text", text: } ], stop_reason:, stop_sequence: nil,
               usage: { input_tokens: 120, output_tokens: 40 } }
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status:, headers: { "Content-Type" => "application/json" }, body: body.to_json)
  end
end

RSpec.configure do |config|
  config.include LlmHelpers
  config.before { LlmClient.provider = LlmClient::FakeProvider.new }
  config.after { LlmClient.provider = nil }
end
