# Turns raw source (Markdown or HTML) into a document body and saves it.
# Works for new and existing documents; returns the document (check #errors on failure).
class DocumentImport
  MAX_BYTES = 5.megabytes

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
    # Re-index only when the text really changed: re-running seeds must not redo work
    @document.status = "pending" if @document.body_changed?
    @document.save
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
