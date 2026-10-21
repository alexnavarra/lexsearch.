# Answers a question in the background and pushes the result to the open page via Turbo Stream
class AskQuestionJob < ApplicationJob
  queue_as :default

  retry_on LlmClient::RetryableError, wait: :polynomially_longer, attempts: 5 do |job, error|
    job.arguments.first.update!(status: "failed", error: error.message)
    job.arguments.first.broadcast_answer
  end
  discard_on ActiveRecord::RecordNotFound

  def perform(question)
    question.update!(status: "answering")
    question.broadcast_answer
    RagAnswerer.new(question).call
  rescue LlmClient::RetryableError
    raise
  rescue StandardError => e
    question.update!(status: "failed", error: "#{e.class}: #{e.message}")
    raise
  ensure
    question.broadcast_answer
  end
end
