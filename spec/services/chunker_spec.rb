require "rails_helper"

RSpec.describe Chunker do
  def chunk(body, title: "Guide", max_tokens: 800) = described_class.new(body, title:, max_tokens:).call

  def paragraph(sentences, word: "word") = Array.new(sentences) { "#{([ word ] * 9).join(' ')} end." }.join(" ")

  it "keeps a short section in one chunk" do
    chunks = chunk("# Indexes\n\nA B-tree index supports equality.\n\nIt also supports ranges.\n")

    expect(chunks.size).to eq(1)
    expect(chunks.first).to have_attributes(
      heading: "Indexes",
      section_ref: "Guide > Indexes",
      content: "A B-tree index supports equality.\n\nIt also supports ranges."
    )
  end

  it "builds section_ref from the heading path" do
    body = "# A\n\none\n\n## B\n\ntwo\n\n### C\n\nthree\n\n## D\n\nfour\n"

    expect(chunk(body).map(&:section_ref)).to eq(
      [ "Guide > A", "Guide > A > B", "Guide > A > B > C", "Guide > A > D" ]
    )
  end

  it "does not repeat a top heading that overlaps the title" do
    expect(chunk("# Guide\n\n## Joins\n\ntext\n").first.section_ref).to eq("Guide > Joins")
    expect(chunk("# Query Interface\n\n## Joins\n\ntext\n", title: "Rails Guides: Query Interface")
      .first.section_ref).to eq("Rails Guides: Query Interface > Joins")
    expect(chunk("# Guide for Rails\n\ntext\n").first.section_ref).to eq("Guide")
  end

  it "uses the title for text before the first heading and skips empty sections" do
    chunks = chunk("Intro text.\n\n# Empty\n\n## Filled\n\nBody.\n")

    expect(chunks.map(&:section_ref)).to eq([ "Guide", "Guide > Empty > Filled" ])
  end

  it "strips Markdown from headings" do
    expect(chunk("## The `where` [method](http://x)\n\ntext\n").first.heading).to eq("The where method")
  end

  it "splits a long section by paragraphs within the limit" do
    body = "# Long\n\n" + Array.new(6) { paragraph(4) }.join("\n\n")
    chunks = chunk(body, max_tokens: 100)

    expect(chunks.size).to be > 1
    expect(chunks).to all(have_attributes(section_ref: "Guide > Long"))
    expect(chunks.map(&:token_count)).to all(be <= 100)
    expect(chunks.map(&:token_count)).to eq(chunks.map { described_class.estimate_tokens(_1.content) })
  end

  it "repeats the last sentence of the previous chunk" do
    first = paragraph(4, word: "alpha")
    body = "# Long\n\n#{first}\n\n#{paragraph(4, word: 'beta')}"
    chunks = chunk(body, max_tokens: 100)

    expect(chunks.size).to eq(2)
    expect(chunks.last.content).to start_with("#{first.split('. ').last}\n\n")
  end

  it "splits an overlong paragraph by sentences" do
    chunks = chunk("# Wall\n\n#{paragraph(30)}", max_tokens: 100)

    expect(chunks.size).to be > 2
    expect(chunks.map(&:token_count)).to all(be <= 100)
    expect(chunks.map(&:content)).to all(end_with("end."))
  end

  it "never splits a code block and ignores # lines inside it" do
    code = "```ruby\n" + Array.new(40) { |i| "# comment #{i}\nputs #{i}" }.join("\n\n") + "\n```"
    chunks = chunk("# Code\n\nIntro.\n\n#{code}\n\nOutro.\n", max_tokens: 100)

    expect(chunks.map(&:content)).to eq([ "Intro.", code, "Outro." ])
    expect(chunks.map(&:section_ref).uniq).to eq([ "Guide > Code" ])
  end

  it "estimates Cyrillic text as denser than Latin" do
    expect(described_class.estimate_tokens("a" * 12)).to eq(3)
    expect(described_class.estimate_tokens("я" * 12)).to eq(4)
  end

  describe "page markers" do
    def page(number) = described_class.page_marker(number)

    it "drops markers from the text and records the page range" do
      body = "#{page(1)}\n\n# Basics\n\nFirst page text.\n\n#{page(2)}\n\nSecond page text.\n"

      expect(chunk(body).map { [ _1.content, _1.page_from, _1.page_to ] })
        .to eq([ [ "First page text.\n\nSecond page text.", 1, 2 ] ])
    end

    it "gives a marker before a heading to the new section and carries the page into later chunks" do
      body = "#{page(1)}\n\n# A\n\n#{paragraph(4)}\n\n#{paragraph(4)}\n\n#{page(3)}\n\n## B\n\nOn page three.\n"
      chunks = chunk(body, max_tokens: 100)

      expect(chunks.map { [ _1.section_ref, _1.page_from, _1.page_to ] })
        .to eq([ [ "Guide > A", 1, 1 ], [ "Guide > A", 1, 1 ], [ "Guide > A > B", 3, 3 ] ])
      expect(chunks.map(&:content).join).not_to include("<!--")
    end

    it "leaves pages empty for documents without markers" do
      expect(chunk("# A\n\ntext\n").first).to have_attributes(page_from: nil, page_to: nil)
    end
  end
end
