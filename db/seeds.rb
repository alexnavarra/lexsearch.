# Idempotent: documents are matched by source_key, unchanged files are not touched.
# Index synchronously: the default async adapter would lose jobs when this process exits.
ActiveJob::Base.queue_adapter = :inline

manifests = [ Rails.root.join("db/seeds/sources.yml"), Rails.root.join("db/seeds/private/sources.yml") ]

manifests.select(&:exist?).each do |manifest|
  documents = SourceManifestImport.new(manifest).call
  puts "#{manifest.relative_path_from(Rails.root)}: #{documents.size} documents"
end

# Documents imported before indexing existed, or whose indexing failed
Document.where(status: %w[pending failed]).find_each { IndexDocumentJob.perform_now(_1) }
puts "#{Chunk.count} chunks in #{Document.indexed.count} indexed documents"
