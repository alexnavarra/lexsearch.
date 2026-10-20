require "rails_helper"

RSpec.describe FulltextSearch do
  def search(query, **options) = described_class.new(query, **options).call

  it "stems words with the chunk's language" do
    russian = create(:chunk, language: "russian", heading: "Индексы", content: "Поиск по индексом ускоряет запросы.")
    english = create(:chunk, language: "english", heading: "Indexes", content: "Indexes are stored separately.")

    expect(search("индексы")).to eq([ russian ])
    expect(search("indexing")).to eq([ english ])
  end

  it "ranks a heading match above a body match" do
    body = create(:chunk, heading: "Maintenance", content: "Run VACUUM FULL rarely.")
    heading = create(:chunk, heading: "VACUUM FULL", content: "Rewrites the table.")

    expect(search("VACUUM FULL")).to eq([ heading, body ])
    expect(search("VACUUM FULL").map(&:rank)).to all(be_positive)
  end

  it "supports websearch syntax: phrases and exclusion" do
    full = create(:chunk, content: "VACUUM FULL rewrites the table.")
    create(:chunk, content: "Full table scan. Autovacuum runs VACUUM.")

    expect(search('"vacuum full"')).to eq([ full ])
    expect(search("vacuum -rewrites").map(&:id)).not_to include(full.id)
  end

  it "builds a snippet with marked matches" do
    create(:chunk, content: "Plain VACUUM reclaims space. <script>alert(1)</script>")

    snippet = search("vacuum").first.snippet

    expect(snippet).to include("#{described_class::MARK_START}VACUUM#{described_class::MARK_STOP}")
  end

  it "returns nothing for blank and stopword-only queries" do
    create(:chunk, content: "the and of")

    expect(search("")).to eq([])
    expect(search("the and и в")).to eq([])
  end

  it "applies topic, language and kind filters" do
    notes = create(:document, kind: "notes", topic: "rails")
    match = create(:chunk, document: notes, content: "eager loading")
    create(:chunk, content: "eager loading", topic: "postgresql")

    expect(search("eager", filters: { topic: "rails", kind: "notes", language: "" })).to eq([ match ])
    expect(search("eager", filters: { kind: "book" })).to eq([])
  end
end
