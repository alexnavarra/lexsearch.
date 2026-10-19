namespace :documents do
  desc "Rebuild chunks for all documents (run after changing the Chunker)"
  task reindex: :environment do
    Document.find_each { IndexDocumentJob.perform_now(_1) }
    puts "#{Chunk.count} chunks in #{Document.indexed.count} indexed documents"
  end
end
