require "rails_helper"

RSpec.describe "pgvector extension" do
  let(:conn) { ActiveRecord::Base.connection }

  it "is installed" do
    expect(conn.select_values("SELECT extname FROM pg_extension")).to include("vector")
  end

  it "computes cosine distance" do
    distance = conn.select_value("SELECT '[0.9,0.8,0]'::vector <=> '[0.8,0.9,0.1]'").to_f
    expect(distance).to be_within(0.01).of(0.01)
  end
end
