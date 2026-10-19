# Idempotent: documents are matched by source_key, unchanged files are not touched.
manifests = [ Rails.root.join("db/seeds/sources.yml"), Rails.root.join("db/seeds/private/sources.yml") ]

manifests.select(&:exist?).each do |manifest|
  documents = SourceManifestImport.new(manifest).call
  puts "#{manifest.relative_path_from(Rails.root)}: #{documents.size} documents"
end
