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

  it "rejects empty, oversized and PDF input with errors" do
    expect(described_class.new(document.dup, raw: "").call.errors[:body]).to be_present
    expect(described_class.new(document.dup, raw: "a" * (DocumentImport::MAX_BYTES + 1)).call.errors[:body]).to be_present

    pdf = document.dup.tap { _1.source_format = "pdf" }
    expect(described_class.new(pdf, raw: "%PDF").call.errors[:body]).to include(/stage 10/)
    expect(Document.count).to eq(0)
  end

  it "infers the format from a file name" do
    expect(described_class.format_for("page.HTML")).to eq("html")
    expect(described_class.format_for("notes.md")).to eq("markdown")
    expect(described_class.format_for("notes.txt")).to eq("markdown")
  end
end
