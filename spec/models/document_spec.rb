require "rails_helper"

RSpec.describe Document do
  it "is valid with factory defaults" do
    expect(build(:document)).to be_valid
  end

  it "requires title, topic and body" do
    document = Document.new(language: "english")

    expect(document).not_to be_valid
    expect(document.errors.attribute_names).to include(:title, :topic, :body)
  end

  it "adds an error for an unknown enum value instead of raising" do
    document = build(:document, kind: "podcast", language: "klingon")

    expect(document).not_to be_valid
    expect(document.errors.attribute_names).to include(:kind, :language)
  end

  it "defaults to pending status and markdown format" do
    document = create(:document)

    expect(document).to be_pending
    expect(document).to be_markdown
  end

  it "normalizes topic and blank source_url" do
    document = build(:document, topic: "  PostgreSQL ", source_url: " ")

    expect(document.topic).to eq("postgresql")
    expect(document.source_url).to be_nil
  end

  it "keeps source_key unique" do
    create(:document, source_key: "rails/guide")

    expect(build(:document, source_key: "rails/guide")).not_to be_valid
  end

  it "lists distinct topics in order" do
    create(:document, topic: "rails")
    create_list(:document, 2, topic: "postgresql")

    expect(Document.topics).to eq(%w[postgresql rails])
  end
end
