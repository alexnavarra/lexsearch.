require "rails_helper"

RSpec.describe "Documents", type: :request do
  let(:attributes) { { title: "Isolation", kind: "notes", topic: "postgresql", language: "" } }

  it "lists documents filtered by topic" do
    create(:document, title: "PG doc", topic: "postgresql")
    create(:document, title: "Rails doc", topic: "rails")

    get documents_path(topic: "rails")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Rails doc")
    expect(response.body).not_to include("PG doc")
  end

  it "creates a document from pasted text" do
    post documents_path, params: { document: attributes.merge(raw: "# Изоляция\n\nТекст.") }

    document = Document.last
    expect(response).to redirect_to(document)
    expect(document).to have_attributes(language: "russian", source_format: "markdown")
  end

  it "creates a document from an uploaded HTML file" do
    file = fixture_file_upload("pg_docs_page.html", "text/html")

    post documents_path, params: { document: attributes.merge(file: file) }

    expect(Document.last).to have_attributes(source_format: "html", language: "english")
    expect(Document.last.body).to start_with("# 11.2. Index Types")
  end

  it "re-renders the form when text is missing" do
    post documents_path, params: { document: attributes.merge(raw: "") }

    expect(response).to have_http_status(:unprocessable_content)
    expect(Document.count).to eq(0)
  end

  it "updates the body as Markdown" do
    document = create(:document, status: "indexed")

    patch document_path(document), params: { document: { title: "New", body: "New\n===\n\nText" } }

    expect(document.reload).to have_attributes(title: "New", body: "# New\n\nText\n", status: "pending")
  end

  it "shows a document with its chunks and destroys it with them" do
    document = create(:document)
    chunk = create(:chunk, document:, section_ref: "Guide > Joins")

    get document_path(document)
    expect(response.body).to include(document.title, "Guide &gt; Joins")

    delete document_path(document)
    expect(response).to redirect_to(documents_path)
    expect(Document.exists?(document.id)).to be(false)
    expect(Chunk.exists?(chunk.id)).to be(false)
  end
end
