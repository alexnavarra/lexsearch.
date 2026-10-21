# The only entry point for LLM calls. Picks a provider by ENV, logs every call to llm_calls
# and hides the SDK: callers see only LlmClient::Response and LlmClient errors.
module LlmClient
  class Error < StandardError; end
  # Rate limits, 5xx, timeouts: worth retrying later (jobs use retry_on)
  class RetryableError < Error; end
  # The model answered, but not with what we asked for (bad JSON, refusal, truncated)
  class InvalidOutput < Error; end

  PROVIDERS = { "anthropic" => "LlmClient::AnthropicProvider", "fake" => "LlmClient::FakeProvider" }.freeze

  Response = Data.define(:text, :stop_reason, :input_tokens, :output_tokens) do
    # Parsed structured output; raises InvalidOutput when the text is not the JSON we asked for
    def json
      raise InvalidOutput, "stop_reason: #{stop_reason}" unless stop_reason == "end_turn"

      JSON.parse(text)
    rescue JSON::ParserError => e
      raise InvalidOutput, "invalid JSON: #{e.message.truncate(200)}"
    end
  end

  # Structured output after validation: errors empty means data matches the schema
  Structured = Data.define(:data, :errors, :response)

  class << self
    # messages: [{ role: "user" | "assistant", content: String }]; schema: JSON schema for structured output
    def call(purpose:, system:, messages:, schema: nil, max_tokens: 8_000, effort: nil)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = provider.complete(system:, messages:, schema:, max_tokens:, effort:)
      log(purpose, started, status: "ok", stop_reason: response.stop_reason,
                            input_tokens: response.input_tokens, output_tokens: response.output_tokens)
      response
    rescue Error => e
      log(purpose, started, status: "error", error: "#{e.class}: #{e.message}".truncate(2_000))
      raise
    end

    # Structured output with one retry: invalid JSON gets the validation errors back as a new turn.
    # validation_schema may carry constraints the API rejects (maxItems, minLength, minimum).
    def call_structured(schema:, messages:, validation_schema: schema, **options)
      validator = JSONSchemer.schema(validation_schema.deep_stringify_keys)
      response = call(schema:, messages:, **options)
      data, errors = validate(response, validator)
      return Structured.new(data:, errors:, response:) if errors.empty?

      messages += [ { role: "assistant", content: response.text.presence || "(empty)" },
                    { role: "user", content: retry_prompt(errors) } ]
      response = call(schema:, messages:, **options)
      Structured.new(*validate(response, validator), response)
    end

    # Without an API key the fake provider is used, so the app works offline
    def provider
      @provider ||= begin
        name = ENV["LLM_PROVIDER"].presence || (ENV["ANTHROPIC_API_KEY"].present? ? "anthropic" : "fake")
        PROVIDERS.fetch(name).constantize.new(model: ENV.fetch("LLM_MODEL", "claude-haiku-5-5"))
      end
    end

    attr_writer :provider

    private

    # [data, errors]; data may be partially usable even with errors
    def validate(response, validator)
      data = response.json
      [ data, validator.validate(data).map { _1["error"] } ]
    rescue InvalidOutput => e
      [ nil, [ e.message ] ]
    end

    def retry_prompt(errors)
      "Your previous answer was invalid:\n#{errors.map { "- #{_1}" }.join("\n")}\nReturn corrected JSON for the same input."
    end

    def log(purpose, started, **attributes)
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      LlmCall.create!(purpose:, provider: provider.name, model: provider.model, duration_ms:, **attributes)
    end
  end
end
