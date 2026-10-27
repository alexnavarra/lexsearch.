# Claude through the official anthropic gem. The SDK itself retries 429/5xx/network errors
# max_retries times; whatever still fails is mapped to LlmClient errors.
class LlmClient::AnthropicProvider
  attr_reader :model

  def initialize(model:, api_key: ENV["ANTHROPIC_API_KEY"], max_retries: 2, timeout: 120)
    @model = model
    @client = Anthropic::Client.new(api_key:, max_retries:, timeout:)
  end

  def name = "anthropic"

  # No temperature: current models reject non-default sampling parameters.
  # Structured output via output_config.format (forced tool_choice is rejected by newer models).
  # cache: a breakpoint after the system prompt. A prefix below the model's minimum (512 tokens on
  # current models) silently is not cached: cache_write_tokens stays 0.
  def complete(system:, messages:, schema:, max_tokens:, effort:, cache: false)
    output_config = { effort:, format_: schema && { type: :json_schema, schema: } }.compact
    system = [ { type: :text, text: system, cache_control: { type: :ephemeral } } ] if cache
    params = { model:, max_tokens:, system_: system, messages: }
    params[:output_config] = output_config if output_config.any?

    message = @client.messages.create(**params)
    LlmClient::Response.new(
      text: message.content.select { _1.type == :text }.map(&:text).join,
      stop_reason: message.stop_reason.to_s,
      input_tokens: message.usage.input_tokens,
      output_tokens: message.usage.output_tokens,
      cache_write_tokens: message.usage.cache_creation_input_tokens.to_i,
      cache_read_tokens: message.usage.cache_read_input_tokens.to_i
    )
  rescue Anthropic::Errors::RateLimitError, Anthropic::Errors::InternalServerError, Anthropic::Errors::APIConnectionError => e
    raise LlmClient::RetryableError, "#{e.class.name.demodulize}: #{e.message}"
  rescue Anthropic::Errors::APIError => e
    raise LlmClient::Error, "#{e.class.name.demodulize}: #{e.message}"
  end
end
