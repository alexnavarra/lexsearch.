class DocumentCardsController < ApplicationController
  # Queues card generation for chunks without cards (or with stub cards, once a real LLM is set)
  def create
    document = Document.find(params[:document_id])
    chunks = document.chunks.where.not(id: chunks_done(document))
    chunks.each { GenerateCardsJob.perform_later(_1) }

    notice = chunks.any? ? "Генерация карточек запущена для #{chunks.size} фрагментов. Обнови страницу через минуту." : "У всех фрагментов уже есть карточки."
    redirect_to document_path(document, anchor: "cards"), notice:
  end

  private

  def chunks_done(document)
    cards = document.cards
    cards = cards.real unless LlmClient.provider.model == LlmClient::FakeProvider::MODEL
    cards.where.not(chunk_id: nil).select(:chunk_id)
  end
end
