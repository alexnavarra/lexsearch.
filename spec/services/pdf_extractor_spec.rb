require "rails_helper"

RSpec.describe PdfExtractor do
  let(:body) { described_class.new(book_pdf).call }

  it "marks pages and takes headings from the PDF outline" do
    expect(body.lines.grep(/<!-- page|^#/).map(&:chomp)).to eq([
      "<!-- page 1 -->", "# Getting Started",
      "<!-- page 2 -->", "## Installing Git",
      "<!-- page 3 -->", "## 1.2 Configuring Identity"
    ])
  end

  it "removes running headers and page numbers" do
    expect(body).not_to include("Tiny Git Book")
    expect(body.lines.map(&:strip)).not_to include("1", "2", "3")
  end

  it "joins wrapped lines, hyphenated words and paragraphs split by a page break" do
    expect(body).to include("branches are cheap to create", "The first replication of a repository")
    expect(body).to include("building from source is rarely needed today.")
  end

  it "keeps bullets as a list and indented text as a code block" do
    expect(body).to include("- Speed\n\n- Simple design", "```\n$ git --version\n* main\nfeature\n```")
  end

  it "keeps an indented note as a paragraph, not code" do
    expect(body).to include("```\n\nThis book was written for Git version 2, and most of the commands work in older versions too.\n\n")
  end

  it "falls back to numbered headings without an outline" do
    headings = described_class.new(book_pdf(outline: false)).call.lines.grep(/^#/)

    expect(headings).to eq([ "## 1.2 Configuring Identity\n" ])
  end

  it "gives the Chunker pages to work with" do
    pieces = Chunker.new(body, title: "Tiny Git Book").call

    expect(pieces.map { [ _1.section_ref, _1.page_from, _1.page_to ] }).to eq([
      [ "Tiny Git Book > Getting Started", 1, 1 ],
      [ "Tiny Git Book > Getting Started > Installing Git", 2, 2 ],
      [ "Tiny Git Book > Getting Started > 1.2 Configuring Identity", 3, 3 ]
    ])
  end

  it "probes the first pages quickly and returns their text" do
    sample = described_class.new(book_pdf).probe(pages: 1)

    expect(sample).to include("Getting Started")
    expect(sample).not_to include("Installing Git")
  end

  it "rejects files that are not PDFs and PDFs without a text layer" do
    expect { described_class.new("not a pdf").call }.to raise_error(PdfExtractor::Error)

    scan = Prawn::Document.new { _1.stroke_rectangle([ 0, 700 ], 100, 100) }.render
    expect { described_class.new(scan).probe }.to raise_error(PdfExtractor::Error, /scan/)
  end
end
