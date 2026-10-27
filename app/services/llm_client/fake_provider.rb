# Offline stand-in for a real model: no network, no cost, deterministic.
# With a schema it returns the smallest JSON that fits it, with strings built from the
# last user message, so different inputs give different (obviously fake) outputs.
class LlmClient::FakeProvider
  MODEL = "fake"

  def initialize(model: nil); end

  def model = MODEL

  def name = "fake"

  def complete(system:, messages:, schema:, max_tokens:, effort:, cache: false)
    source = messages.reverse.find { _1[:role].to_s == "user" }&.dig(:content).to_s
    excerpt = source.gsub(/<[^>]+>/, " ").squish.truncate(80)
    text = schema ? JSON.generate(sample(schema.deep_symbolize_keys, excerpt)) : "[stub] #{excerpt}#{citation(source)}"
    LlmClient::Response.new(text:, stop_reason: "end_turn", input_tokens: 0, output_tokens: 0)
  end

  private

  # Cites the first numbered source if the prompt has one, so citation UI works offline
  def citation(source) = source.include?('id="S1"') ? " [S1]" : ""

  def sample(schema, excerpt, key = nil)
    return schema[:enum].first if schema[:enum]

    case schema[:type]
    when "object" then schema.fetch(:required, []).to_h { [ _1, sample(schema[:properties][_1.to_sym], excerpt, _1) ] }
    when "array" then [ sample(schema[:items], excerpt, key) ]
    when "integer", "number" then 0
    when "boolean" then false
    else "[stub #{key}] #{excerpt}"
    end
  end
end
