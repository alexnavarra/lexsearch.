require "rails_helper"

RSpec.describe HybridSearch do
  before { stub_embeddings }

  def chunk(content, **attributes)
    create(:chunk, content:, section_ref: "S", embedding: EmbeddingsHelpers.vector_for("S\n\n#{content}"),
                   embedding_model: "bge-m3", **attributes)
  end

  it "fuses ranks with RRF: found by both methods beats found by one" do
    both = chunk("vacuum full rewrites table")
    vector_only = chunk("vacuuming maintenance", language: "russian") # russian stemming keeps it out of fulltext
    fulltext_only = chunk("table rewrites")

    results = described_class.new("vacuum full table").call

    expect(results.first).to have_attributes(chunk: both, vector_rank: 1, fulltext_rank: 1)
    expect(results.first.score).to be_within(1e-9).of(2.0 / 61)
    expect(results.map(&:chunk)).to include(vector_only, fulltext_only)
  end

  it "gives the same order in Ruby and SQL" do
    words = %w[vacuum index table lock row page heap btree gin scan]
    20.times { |i| chunk(words.rotate(i).first(3 + i % 4).join(" "), topic: i.even? ? "postgresql" : "rails") }

    [ "vacuum table", "index scan heap", "lock" ].each do |query|
      [ {}, { topic: "rails" } ].each do |filters|
        ruby = described_class.new(query, filters:, strategy: :ruby).call
        sql = described_class.new(query, filters:, strategy: :sql).call

        expect(sql.map { [ _1.chunk.id, _1.vector_rank, _1.fulltext_rank ] })
          .to eq(ruby.map { [ _1.chunk.id, _1.vector_rank, _1.fulltext_rank ] })
        expect(sql.map(&:score)).to eq(ruby.map(&:score))
      end
    end
  end

  it "still works when full-text finds nothing" do
    only = chunk("vacuum")

    expect(described_class.new("the и").call.map(&:chunk)).to eq([ only ])
    expect(described_class.new("the и", strategy: :sql).call.map(&:chunk)).to eq([ only ])
  end

  it "embeds the query once" do
    chunk("vacuum")

    described_class.new("vacuum").call

    expect(a_request(:post, %r{/api/embed})).to have_been_made.once
  end
end
