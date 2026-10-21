# Grades an exam answer in the background and pushes the verdict to the open page via Turbo Stream
class GradeAttemptJob < ApplicationJob
  queue_as :default

  retry_on LlmClient::RetryableError, wait: :polynomially_longer, attempts: 5 do |job, error|
    job.arguments.first.update!(status: "failed", error: error.message)
    job.arguments.first.broadcast_verdict
  end
  discard_on ActiveRecord::RecordNotFound

  def perform(attempt)
    attempt.update!(status: "grading")
    attempt.broadcast_verdict
    AnswerGrader.new(attempt).call
  rescue LlmClient::RetryableError
    raise
  rescue StandardError => e
    attempt.update!(status: "failed", error: "#{e.class}: #{e.message}")
    raise
  ensure
    attempt.broadcast_verdict
  end
end
