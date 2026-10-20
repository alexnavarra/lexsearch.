# Local embeddings through the Ollama HTTP API (POST /api/embed takes a batch of texts).
class Embeddings::OllamaProvider
  # Some models are trained with task prefixes; bge-m3 needs none
  PREFIXES = { "nomic-embed-text" => { document: "search_document: ", query: "search_query: " } }.freeze

  attr_reader :model, :dimensions

  def initialize(model:, dimensions:, url: ENV.fetch("OLLAMA_URL", "http://localhost:11434"))
    @model, @dimensions = model, dimensions
    @http = Faraday.new(url:, request: { open_timeout: 5, timeout: 300 }) do |f|
      f.request :json
      f.response :json
      f.response :raise_error
    end
  end

  def embed_documents(texts)
    return [] if texts.empty?

    embed(texts.map { "#{prefix(:document)}#{_1}" })
  end

  def embed_query(text) = embed([ "#{prefix(:query)}#{text}" ]).first

  private

  def prefix(kind) = PREFIXES.dig(model.delete_suffix(":latest"), kind)

  def embed(inputs)
    vectors = @http.post("/api/embed", { model:, input: inputs }).body.fetch("embeddings")
    unless vectors.size == inputs.size && vectors.all? { _1.size == dimensions }
      raise Embeddings::Error, "#{model} returned #{vectors.map(&:size).uniq} dims for #{vectors.size}/#{inputs.size} texts, " \
                               "expected #{dimensions} (check EMBEDDING_DIM)"
    end
    vectors
  rescue Faraday::Error => e
    raise Embeddings::Error, "Ollama #{model}: #{e.message}"
  end
end
