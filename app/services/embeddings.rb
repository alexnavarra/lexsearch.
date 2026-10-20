# The only entry point for embeddings. The provider is chosen by ENV, so swapping
# the model never touches callers. Same model for documents and queries, always.
module Embeddings
  class Error < StandardError; end

  PROVIDERS = { "ollama" => "Embeddings::OllamaProvider" }.freeze

  class << self
    delegate :embed_documents, :embed_query, :model, to: :provider

    def provider
      @provider ||= PROVIDERS.fetch(ENV.fetch("EMBEDDING_PROVIDER", "ollama")).constantize.new(
        model: ENV.fetch("EMBEDDING_MODEL", "bge-m3"),
        dimensions: Integer(ENV.fetch("EMBEDDING_DIM", 1024))
      )
    end

    attr_writer :provider
  end
end
