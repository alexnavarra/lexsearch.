FactoryBot.define do
  factory :document do
    sequence(:title) { "Document #{_1}" }
    kind { "docs" }
    topic { "postgresql" }
    language { "english" }
    body { "# Indexes\n\nA B-tree index supports equality and range queries.\n" }
  end
end
