# Turns raw source (Markdown or HTML) into a document body and saves it.
# Works for new and existing documents; returns the document (check #errors on failure).
class DocumentImport
  MAX_BYTES = 5.megabytes
  # Chunks copy these fields, so a change in any of them means re-indexing
  INDEXED_ATTRIBUTES = %w[body title topic language].freeze

  def self.format_for(filename)
    File.extname(filename.to_s).downcase.in?(%w[.html .htm]) ? "html" : "markdown"
  end

  def initialize(document, raw:, format: document.source_format)
    @document, @raw, @format = document, raw, format.to_s
  end

  def call
    return fail_with("is larger than #{MAX_BYTES / 1.megabyte} MB") if @raw.to_s.bytesize > MAX_BYTES
    return fail_with("import arrives at stage 10") if @format == "pdf"

    @document.body = convert(@raw.to_s.dup.force_encoding("UTF-8").scrub)
    @document.language = LanguageDetector.call(@document.body) if @document.language.blank?
    # Re-index only when indexed data really changed: re-running seeds must not redo work
    reindex = @document.changed.intersect?(INDEXED_ATTRIBUTES)
    @document.status = "pending" if reindex
    IndexDocumentJob.perform_later(@document) if @document.save && reindex
    @document
  end

  private

  def convert(text)
    @format == "html" ? HtmlToMarkdown.new(text).call : MarkdownNormalizer.new(text).call
  end

  def fail_with(message)
    @document.errors.add(:body, message)
    @document
  end
end
