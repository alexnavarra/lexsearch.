require "rails_helper"

RSpec.describe IndexDocumentJob do
  let(:document) do
    create(:document, title: "PG", topic: "postgresql", language: "english",
                      body: "# Indexes\n\nB-tree.\n\n## GIN\n\nFor arrays and full text.\n")
  end

  before { stub_embeddings }

  it "replaces chunks, embeds them and marks the document indexed" do
    create(:chunk, document:, content: "stale")

    described_class.perform_now(document)

    expect(document.reload).to be_indexed
    expect(document.chunks.pluck(:position, :section_ref, :content)).to eq(
      [ [ 0, "PG > Indexes", "B-tree." ], [ 1, "PG > Indexes > GIN", "For arrays and full text." ] ]
    )
    expect(document.chunks.first).to have_attributes(topic: "postgresql", language: "english", token_count: 2)
    expect(document.chunks.pluck(:embedding_model)).to all(eq("bge-m3"))
  end

  it "keeps the vectors of unchanged chunks and embeds only new text" do
    described_class.perform_now(document)
    kept = document.chunks.first.embedding
    document.update!(body: document.body.sub("For arrays and full text.", "For arrays, jsonb and full text."))

    described_class.perform_now(document)

    expect(document.chunks.first.embedding).to eq(kept)
    expect(WebMock).to have_requested(:post, %r{/api/embed})
      .with { JSON.parse(_1.body)["input"] == [ "PG > Indexes > GIN\n\nFor arrays, jsonb and full text." ] }
    expect(document.chunks.pluck(:embedding_model)).to all(eq("bge-m3"))
  end

  it "marks the document failed and re-raises on error" do
    allow(Chunker).to receive(:new).and_raise(ArgumentError, "boom")

    expect { described_class.perform_now(document) }.to raise_error(ArgumentError)
    expect(document.reload).to be_failed
  end

  it "marks the document failed when embeddings are unavailable" do
    stub_request(:post, %r{/api/embed}).to_timeout

    expect { described_class.perform_now(document) }.to raise_error(Embeddings::Error)
    expect(document.reload).to be_failed
  end

  describe "PDF" do
    let(:pdf_document) do
      build(:document, title: "Tiny Git Book", source_format: "pdf", body: "").tap do
        _1.source_file.attach(io: StringIO.new(book_pdf), filename: "book.pdf", content_type: "application/pdf")
        _1.save!
      end
    end

    it "extracts the body from the attached file and stores pages on chunks" do
      described_class.perform_now(pdf_document)

      expect(pdf_document.reload).to be_indexed
      expect(pdf_document.body).to include("<!-- page 2 -->")
      expect(pdf_document.chunks.pluck(:page_from, :page_to)).to eq([ [ 1, 1 ], [ 2, 2 ], [ 3, 3 ] ])
    end

    it "fails without retrying when the PDF cannot be read" do
      pdf_document.source_file.attach(io: StringIO.new("junk"), filename: "book.pdf", content_type: "application/pdf")

      expect { described_class.perform_now(pdf_document) }.not_to raise_error
      expect(pdf_document.reload).to have_attributes(status: "failed", index_error: /PDF/)
    end
  end
end
