require "rails_helper"

RSpec.describe LlmClient::FakeProvider do
  it "returns JSON that satisfies the schema, built from the user message" do
    response = described_class.new.complete(system: "s", messages: [ { role: "user", content: "<source>GIN indexes</source>" } ],
                                            schema: CardGenerator::SCHEMA, max_tokens: 100, effort: nil)

    data = JSON.parse(response.text)
    expect(JSONSchemer.schema(CardGenerator::VALIDATION_SCHEMA).valid?(data)).to be(true)
    expect(data["cards"].first["prompt"]).to include("GIN indexes")
  end
end
