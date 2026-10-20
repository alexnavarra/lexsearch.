FactoryBot.define do
  factory :card do
    chunk
    document { chunk.document }
    prompt { "When to use a GIN index?" }
    reference_answer { "For values with several elements, such as jsonb." }
    kind { "concept" }
    difficulty { "middle" }
    llm_model { "claude-haiku-5-5" }
  end
end
