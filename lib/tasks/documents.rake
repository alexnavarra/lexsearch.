namespace :documents do
  desc "Rebuild chunks and embeddings for all documents (run after changing the Chunker)"
  task reindex: :environment do
    Document.find_each { IndexDocumentJob.perform_now(_1) }
    puts "#{Chunk.count} chunks in #{Document.indexed.count} indexed documents"
  end

  desc "Embed chunks that lack a vector from the current EMBEDDING_MODEL (run after changing the model)"
  task embed: :environment do
    Document.find_each { EmbedChunksJob.perform_now(_1) }
    puts "#{Chunk.where(embedding_model: Embeddings.model).count}/#{Chunk.count} chunks embedded with #{Embeddings.model}"
  end
end
