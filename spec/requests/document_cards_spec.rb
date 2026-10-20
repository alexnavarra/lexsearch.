require "rails_helper"

RSpec.describe "Document cards", type: :request do
  it "queues generation for chunks without cards" do
    document = create(:document)
    done = create(:chunk, document:)
    create(:card, chunk: done, document:)
    pending = create(:chunk, document:)

    expect { post document_cards_path(document) }.to have_enqueued_job(GenerateCardsJob).with(pending).exactly(:once)
    expect(response).to redirect_to(document_path(document, anchor: "cards"))
  end

  it "requeues chunks with stub cards once a real model is configured" do
    document = create(:document)
    stub = create(:chunk, document:)
    create(:card, chunk: stub, document:, llm_model: "fake")
    script_llm

    expect { post document_cards_path(document) }.to have_enqueued_job(GenerateCardsJob).with(stub)
  end

  it "shows cards and the fake-provider warning on the document page" do
    card = create(:card, prompt: "What is MVCC?")
    create(:card, chunk: card.chunk, document: card.document, status: "needs_review", prompt: nil,
                  validation_errors: { "errors" => [ "bad kind" ] })

    get document_path(card.document)

    expect(response.body).to include("What is MVCC?", "needs_review", "bad kind", "LLM-заглушка")
  end
end
