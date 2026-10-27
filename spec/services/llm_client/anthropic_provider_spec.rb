require "rails_helper"

RSpec.describe LlmClient::AnthropicProvider do
  subject(:provider) { described_class.new(model: "claude-haiku-5-5", api_key: "test-key", max_retries: 0) }

  let(:schema) { { type: "object", required: %w[a], properties: { a: { type: "string" } }, additionalProperties: false } }

  def complete(**options)
    provider.complete(system: "sys", messages: [ { role: "user", content: "hi" } ], schema: nil, max_tokens: 100, effort: nil, **options)
  end

  it "sends structured output settings and no temperature" do
    stub_anthropic(text: '{"a":"b"}')

    response = complete(schema:, effort: :low)

    expect(response).to have_attributes(text: '{"a":"b"}', stop_reason: "end_turn", input_tokens: 120, output_tokens: 40)
    expect(a_request(:post, "https://api.anthropic.com/v1/messages").with { |request|
      body = JSON.parse(request.body)
      body["output_config"] == { "effort" => "low", "format" => { "type" => "json_schema", "schema" => schema.deep_stringify_keys } } &&
        body["system"] == "sys" && body["model"] == "claude-haiku-5-5" && !body.key?("temperature")
    }).to have_been_made
  end

  it "marks the system prompt for caching and reads cache usage" do
    stub_anthropic(body: { id: "msg_1", type: "message", role: "assistant", model: "claude-haiku-5-5",
                           content: [ { type: "text", text: "ok" } ], stop_reason: "end_turn", stop_sequence: nil,
                           usage: { input_tokens: 20, output_tokens: 5, cache_creation_input_tokens: 0, cache_read_input_tokens: 700 } })

    response = complete(cache: true)

    expect(response).to have_attributes(input_tokens: 20, cache_write_tokens: 0, cache_read_tokens: 700)
    expect(a_request(:post, %r{/v1/messages}).with { |request|
      JSON.parse(request.body)["system"] == [ { "type" => "text", "text" => "sys", "cache_control" => { "type" => "ephemeral" } } ]
    }).to have_been_made
  end

  it "omits output_config for plain text requests" do
    stub_anthropic(text: "plain")

    complete

    expect(a_request(:post, %r{/v1/messages}).with { !JSON.parse(_1.body).key?("output_config") }).to have_been_made
  end

  it "maps 429 and 5xx to RetryableError" do
    stub_anthropic(status: 429, body: { type: "error", error: { type: "rate_limit_error", message: "slow down" } })
    expect { complete }.to raise_error(LlmClient::RetryableError, /RateLimitError/)

    stub_anthropic(status: 529, body: { type: "error", error: { type: "overloaded_error", message: "busy" } })
    expect { complete }.to raise_error(LlmClient::RetryableError)
  end

  it "maps other API errors to Error" do
    stub_anthropic(status: 400, body: { type: "error", error: { type: "invalid_request_error", message: "bad" } })

    expect { complete }.to raise_error(an_instance_of(LlmClient::Error))
  end
end
