# Deterministic fake embeddings: each text maps to a fixed unit-ish vector derived from its words,
# so texts sharing words are close. Real Ollama is never called in tests.
module EmbeddingsHelpers
  DIMS = 1024

  def self.vector_for(text)
    vector = Array.new(DIMS, 0.0)
    text.downcase.scan(/[[:alnum:]]+/).each { |word| vector[Zlib.crc32(word) % DIMS] += 1.0 }
    vector[0] += 0.001 # never a zero vector
    vector
  end

  def stub_embeddings(url: "http://localhost:11434")
    stub_request(:post, "#{url}/api/embed").to_return do |request|
      inputs = JSON.parse(request.body).fetch("input")
      { status: 200, headers: { "Content-Type" => "application/json" },
        body: { embeddings: inputs.map { EmbeddingsHelpers.vector_for(_1) } }.to_json }
    end
  end
end

RSpec.configure do |config|
  config.include EmbeddingsHelpers
  config.before do
    # Pin the provider so tests don't depend on the developer's .env
    Embeddings.provider = Embeddings::OllamaProvider.new(model: "bge-m3", dimensions: EmbeddingsHelpers::DIMS, url: "http://localhost:11434")
  end
  config.after { Embeddings.provider = nil }
end
