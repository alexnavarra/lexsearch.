require "rails_helper"

RSpec.describe LanguageDetector do
  it "detects Russian text even with Latin terms inside" do
    expect(described_class.call("Индекс GIN ускоряет запросы `@>` по jsonb-колонкам")).to eq("russian")
  end

  it "detects English text" do
    expect(described_class.call("A GIN index speeds up containment queries")).to eq("english")
  end

  it "treats English text with a few Russian words as English" do
    expect(described_class.call("Eager loading solves the N+1 problem (проблема N+1) in Active Record")).to eq("english")
  end

  it "defaults to English when there are no letters" do
    expect(described_class.call("123 + 456")).to eq("english")
    expect(described_class.call(nil)).to eq("english")
  end
end
