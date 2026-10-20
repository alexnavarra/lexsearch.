# Generates cards for one chunk. One job per chunk: a failure or retry touches one LLM call only.
class GenerateCardsJob < ApplicationJob
  queue_as :default

  retry_on LlmClient::RetryableError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(chunk)
    # Stub cards give way to a real model; real cards are never regenerated
    Card.fake.where(chunk:).delete_all unless LlmClient.provider.model == LlmClient::FakeProvider::MODEL
    return if chunk.cards.exists?

    CardGenerator.new(chunk).call
  end
end
