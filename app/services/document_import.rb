# Turns raw source (Markdown, HTML or PDF) into a document body and saves it.
# A PDF is only checked and attached here; IndexDocumentJob extracts its text (slow on a book).
# Works for new and existing documents; returns the document (check #errors on failure).
class DocumentImport
  MAX_BYTES = 10.megabytes
  FORMATS = { ".html" => "html", ".htm" => "html", ".pdf" => "pdf" }.freeze
  # Chunks copy these fields, so a change in any of them means re-indexing
  INDEXED_ATTRIBUTES = %w[body title topic language].freeze

  def self.format_for(filename)
    FORMATS.fetch(File.extname(filename.to_s).downcase, "markdown")
  end

  # filename: original name of an uploaded PDF
  def initialize(document, raw:, format: document.source_format, filename: nil)
    @document, @raw, @format, @filename = document, raw, format.to_s, filename
  end

  def call
    return fail_with("is larger than #{MAX_BYTES / 1.megabyte} MB") if @raw.to_s.bytesize > MAX_BYTES
    return import_pdf if @format == "pdf"

    @document.body = convert(@raw.to_s.dup.force_encoding("UTF-8").scrub)
    @document.language = LanguageDetector.call(@document.body) if @document.language.blank?
    save_and_index
  end

  private

  def import_pdf
    data = @raw.to_s.b
    # Same file again (seeds re-run): nothing to do
    return @document if @document.persisted? && @document.source_file.attached? &&
                        @document.source_file.checksum == Digest::MD5.base64digest(data)

    sample = PdfExtractor.new(data).probe
    @document.language = LanguageDetector.call(sample) if @document.language.blank?
    @document.source_file.attach(io: StringIO.new(data), filename: @filename || "#{@document.title.parameterize}.pdf",
                                 content_type: "application/pdf")
    @document.body = "" # extracted by IndexDocumentJob
    @document.index_error = nil
    save_and_index
  rescue PdfExtractor::Error => e
    @document.errors.add(:base, "PDF не читается: #{e.message}")
    @document
  end

  def save_and_index
    # Re-index only when indexed data really changed: re-running seeds must not redo work
    reindex = @document.changed.intersect?(INDEXED_ATTRIBUTES)
    @document.status = "pending" if reindex
    IndexDocumentJob.perform_later(@document) if @document.save && reindex
    @document
  end

  def convert(text)
    @format == "html" ? HtmlToMarkdown.new(text).call : MarkdownNormalizer.new(text).call
  end

  def fail_with(message)
    @document.errors.add(:body, message)
    @document
  end
end
