require "rails_helper"

RSpec.describe SourceManifestImport do
  let(:root) { file_fixture("manifest") }
  let(:import) { described_class.new(root.join("sources.yml"), root: root) }

  it "creates documents from the manifest" do
    import.call

    guide = Document.find_by!(source_key: "test/guide")
    expect(guide).to have_attributes(title: "Guide", topic: "rails", source_format: "markdown", language: "english")
    expect(guide.body).to start_with("# Guide Title\n")

    page = Document.find_by!(source_key: "test/page")
    expect(page).to have_attributes(source_format: "html", source_url: "https://example.com/page", body: "# Page\n\nText.\n")
  end

  it "is idempotent: a second run creates and updates nothing" do
    import.call
    Document.update_all(status: "indexed", updated_at: 1.day.ago)

    expect { import.call }.not_to change { Document.pluck(:id, :status, :updated_at).sort }
  end

  it "updates metadata of an existing document by key" do
    import.call
    Document.find_by!(source_key: "test/guide").update!(title: "Old title")

    import.call

    expect(Document.find_by!(source_key: "test/guide").title).to eq("Guide")
    expect(Document.count).to eq(2)
  end
end
