require "rails_helper"

RSpec.describe AskQuestionJob do
  include ActiveJob::TestHelper

  let(:question) { Question.create!(text: "what is hnsw") }
  let(:stream) { question.to_gid_param }

  before { stub_embeddings }

  it "answers and pushes the result to the page" do
    expect { described_class.perform_now(question) }.to have_broadcasted_to(stream).at_least(:twice)
    expect(question.reload).to be_not_found # no chunks in the test database
  end

  it "re-enqueues on rate limits" do
    create(:chunk, content: "hnsw graph", embedding: EmbeddingsHelpers.vector_for("x"), embedding_model: "bge-m3")
    script_llm(LlmClient::RetryableError.new("429"))

    expect { described_class.perform_now(question) }.to have_enqueued_job(described_class)
    expect(question.reload).to be_answering
  end

  it "marks the question failed on other errors" do
    stub_request(:post, %r{/api/embed}).to_timeout

    expect { described_class.perform_now(question) }.to raise_error(Embeddings::Error)
    expect(question.reload).to have_attributes(status: "failed", error: /Embeddings::Error/)
  end
end
