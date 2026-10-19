FactoryBot.define do
  factory :chunk do
    document
    sequence(:position)
    section_ref { "#{document.title} > Indexes" }
    heading { "Indexes" }
    content { "A B-tree index supports equality and range queries." }
    token_count { Chunker.estimate_tokens(content) }
    topic { document.topic }
    language { document.language }
  end
end
