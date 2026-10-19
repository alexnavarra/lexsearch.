# Loads documents listed in a YAML manifest. Idempotent: documents are matched by `key`,
# so running it twice creates nothing new and changes nothing if files are unchanged.
class SourceManifestImport
  ATTRIBUTES = %w[title kind topic language source_url].freeze

  def initialize(manifest_path, root: Rails.root)
    @manifest_path, @root = Pathname(manifest_path), Pathname(root)
  end

  def call
    entries.map do |entry|
      path = @root.join(entry.fetch("file"))
      document = Document.find_or_initialize_by(source_key: entry.fetch("key"))
      document.assign_attributes(entry.slice(*ATTRIBUTES))
      document.source_format = DocumentImport.format_for(path)

      DocumentImport.new(document, raw: path.read).call
      raise ActiveRecord::RecordInvalid, document if document.errors.any?

      document
    end
  end

  private

  def entries = YAML.safe_load_file(@manifest_path).fetch("documents")
end
