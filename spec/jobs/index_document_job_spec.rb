require "rails_helper"

RSpec.describe IndexDocumentJob do
  let(:document) do
    create(:document, title: "PG", topic: "postgresql", language: "english",
                      body: "# Indexes\n\nB-tree.\n\n## GIN\n\nFor arrays and full text.\n")
  end

  it "replaces chunks and marks the document indexed" do
    create(:chunk, document:, content: "stale")

    described_class.perform_now(document)

    expect(document.reload).to be_indexed
    expect(document.chunks.pluck(:position, :section_ref, :content)).to eq(
      [ [ 0, "PG > Indexes", "B-tree." ], [ 1, "PG > Indexes > GIN", "For arrays and full text." ] ]
    )
    expect(document.chunks.first).to have_attributes(topic: "postgresql", language: "english", token_count: 2)
  end

  it "marks the document failed and re-raises on error" do
    allow(Chunker).to receive(:new).and_raise(ArgumentError, "boom")

    expect { described_class.perform_now(document) }.to raise_error(ArgumentError)
    expect(document.reload).to be_failed
  end
end
