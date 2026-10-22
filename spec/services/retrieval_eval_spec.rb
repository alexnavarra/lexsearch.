require "rails_helper"

RSpec.describe RetrievalEval do
  describe ".metrics" do
    it "computes recall@k and MRR from places" do
      metrics = described_class.metrics([ 1, 3, nil, 7 ])

      expect(metrics.count).to eq(4)
      expect(metrics.recall).to eq(1 => 0.25, 5 => 0.5, 10 => 0.75)
      expect(metrics.mrr).to be_within(0.001).of((1 + 1.0 / 3 + 0 + 1.0 / 7) / 4)
    end

    it "is zero for an empty set" do
      expect(described_class.metrics([])).to have_attributes(count: 0, mrr: 0.0, recall: { 1 => 0.0, 5 => 0.0, 10 => 0.0 })
    end
  end

  describe RetrievalEval::Item do
    it "matches a section and its subsections, not siblings with the same prefix" do
      item = described_class.new(question: "q", language: "en", expected: [ "Guide > HNSW" ], chunk_id: nil)

      expect(item.relevant?(Chunk.new(section_ref: "Guide > HNSW"))).to be(true)
      expect(item.relevant?(Chunk.new(section_ref: "Guide > HNSW > Query Options"))).to be(true)
      expect(item.relevant?(Chunk.new(section_ref: "Guide > HNSW2"))).to be(false)
    end

    it "is answerable only when an expected section exists in the database" do
      create(:chunk, section_ref: "Guide > HNSW > Query Options")
      item = ->(ref) { described_class.new(question: "q", language: "en", expected: [ ref ], chunk_id: nil) }

      expect(item.("Guide > HNSW")).to be_answerable
      expect(item.("Guide > HNSW > Query Options")).to be_answerable
      expect(item.("Guide > HNS")).not_to be_answerable
      expect(item.("Pro Git > Branching")).not_to be_answerable
    end
  end

  it "loads the bundled set: 35 questions (5 on a private book), 17 in Russian, all with expected sections" do
    items = described_class.load(Rails.root.join("spec/evals/retrieval.yml"))

    expect(items.size).to eq(35)
    expect(items.count { _1.language == "ru" }).to eq(17)
    expect(items.map(&:expected)).to all(be_present)
  end

  it "finds the place of the first relevant chunk in every mode" do
    stub_embeddings
    target = create(:chunk, section_ref: "Guide > VACUUM", heading: "VACUUM", content: "VACUUM reclaims storage",
                            embedding: EmbeddingsHelpers.vector_for("reclaim disk space"), embedding_model: "bge-m3")
    create(:chunk, section_ref: "Guide > Other", content: "unrelated", embedding: EmbeddingsHelpers.vector_for("other"),
                   embedding_model: "bge-m3")
    items = [ RetrievalEval::Item.new(question: "reclaim disk space", language: "en", expected: [ "Guide > VACUUM" ], chunk_id: nil),
              RetrievalEval::Item.new(question: "vacuum", language: "ru", expected: [], chunk_id: target.id) ]

    eval = described_class.new(items)

    expect(eval.places[:vector].first).to eq(1)
    expect(eval.places[:fulltext]).to eq([ nil, 1 ]) # no shared words in the first question
    expect(eval.places[:hybrid].first).to eq(1)
    expect(eval.report[[ :fulltext, "ru" ]].recall[1]).to eq(1.0)
    expect(eval.report.keys.map(&:last).uniq).to eq(%w[all en ru])
  end
end
