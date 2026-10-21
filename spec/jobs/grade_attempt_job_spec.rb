require "rails_helper"

RSpec.describe GradeAttemptJob do
  include ActiveJob::TestHelper

  let(:attempt) { create(:card).attempts.create!(answer: "jsonb") }
  let(:stream) { attempt.to_gid_param }

  it "grades and pushes the verdict to the page" do
    expect { described_class.perform_now(attempt) }.to have_broadcasted_to(stream).at_least(:twice)
    expect(attempt.reload).to be_graded
  end

  it "re-enqueues on rate limits" do
    script_llm(LlmClient::RetryableError.new("429"))

    expect { described_class.perform_now(attempt) }.to have_enqueued_job(described_class)
    expect(attempt.reload).to be_grading
  end

  it "marks the attempt failed on other errors" do
    script_llm(RuntimeError.new("boom"))

    expect { described_class.perform_now(attempt) }.to raise_error(RuntimeError)
    expect(attempt.reload).to have_attributes(status: "failed", error: /boom/)
  end
end
