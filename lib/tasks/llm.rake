namespace :llm do
  desc "LLM spend by model and purpose: DAYS=30 (default) or FROM=2026-10-01 [TO=2026-10-31]"
  task costs: :environment do
    from = ENV["FROM"] ? Date.parse(ENV["FROM"]).beginning_of_day : Integer(ENV.fetch("DAYS", 30)).days.ago
    to = ENV["TO"] ? Date.parse(ENV["TO"]).end_of_day : Time.current
    puts LlmCostReport.new(from:, to:)
  end
end
