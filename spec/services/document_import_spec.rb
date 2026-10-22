require "rails_helper"

RSpec.describe DocumentImport do
  let(:document) { Document.new(title: "Notes", kind: "notes", topic: "rails") }

  it "normalizes Markdown and detects the language" do
    result = described_class.new(document, raw: "Заголовок\n=========\n\nТекст про индексы.").call

    expect(result).to be_persisted
    expect(result.body).to eq("# Заголовок\n\nТекст про индексы.\n")
    expect(result).to be_language_russian
  end

  it "converts HTML when the format is html" do
    document.source_format = "html"
    result = described_class.new(document, raw: "<main><h2>Title</h2><p>Text</p></main>").call

    expect(result.body).to eq("# Title\n\nText\n")
  end

  it "keeps an explicitly chosen language" do
    document.language = "english"
    result = described_class.new(document, raw: "Только русский текст").call

    expect(result).to be_language_english
  end

  it "re-indexes only when indexed data changes" do
    indexed = create(:document, status: "indexed", body: "# Same\n")

    expect { described_class.new(indexed, raw: "# Same").call }.not_to have_enqueued_job(IndexDocumentJob)
    expect(indexed.reload).to be_indexed

    expect { described_class.new(indexed, raw: "# Changed").call }.to have_enqueued_job(IndexDocumentJob).with(indexed)
    expect(indexed.reload).to be_pending

    indexed.update!(status: "indexed", topic: "rails")
    expect { described_class.new(indexed, raw: "# Changed").call }.not_to have_enqueued_job(IndexDocumentJob)
    indexed.topic = "postgresql"
    expect { described_class.new(indexed, raw: "# Changed").call }.to have_enqueued_job(IndexDocumentJob)
  end

  it "does not enqueue indexing when the document is invalid" do
    expect { described_class.new(Document.new, raw: "text").call }.not_to have_enqueued_job
  end

  it "fixes invalid UTF-8 bytes instead of failing" do
    result = described_class.new(document, raw: "caf\xC3 au lait".b).call

    expect(result).to be_persisted
    expect(result.body).to be_valid_encoding
  end

  it "rejects empty and oversized input with errors" do
    expect(described_class.new(document.dup, raw: "").call.errors[:body]).to be_present
    expect(described_class.new(document.dup, raw: "a" * (DocumentImport::MAX_BYTES + 1)).call.errors[:body]).to be_present
    expect(Document.count).to eq(0)
  end

  describe "PDF" do
    let(:pdf) { document.tap { _1.source_format = "pdf" } }

    it "attaches the file, detects the language and leaves extraction to the job" do
      result = nil
      expect { result = described_class.new(pdf, raw: book_pdf, filename: "book.pdf").call }
        .to have_enqueued_job(IndexDocumentJob)

      expect(result).to be_persisted
      expect(result).to have_attributes(body: "", status: "pending", language: "english")
      expect(result.source_file.filename.to_s).to eq("book.pdf")
    end

    it "does nothing when the same file is imported again" do
      described_class.new(pdf, raw: book_pdf).call
      pdf.update!(status: "indexed", body: "# Extracted\n")

      expect { described_class.new(pdf, raw: book_pdf).call }.not_to have_enqueued_job
      expect(pdf.reload.body).to eq("# Extracted\n")
    end

    it "explains why a PDF cannot be read and saves nothing" do
      result = described_class.new(pdf, raw: "%PDF-1.4 broken").call

      expect(result.errors[:base].first).to start_with("PDF не читается")
      expect(Document.count).to eq(0)
    end
  end

  it "infers the format from a file name" do
    expect(described_class.format_for("page.HTML")).to eq("html")
    expect(described_class.format_for("notes.md")).to eq("markdown")
    expect(described_class.format_for("notes.txt")).to eq("markdown")
    expect(described_class.format_for("Book.PDF")).to eq("pdf")
  end
end
