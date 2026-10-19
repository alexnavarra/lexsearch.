require "webmock/rspec"
require "vcr"

# No real HTTP in tests: LLM and embedding calls must be stubbed or recorded
WebMock.disable_net_connect!(allow_localhost: false)

VCR.configure do |c|
  c.cassette_library_dir = Rails.root.join("spec/cassettes").to_s
  c.hook_into :webmock
  c.configure_rspec_metadata!
  c.filter_sensitive_data("<ANTHROPIC_API_KEY>") { ENV["ANTHROPIC_API_KEY"] }
end
