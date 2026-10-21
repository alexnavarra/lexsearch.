namespace :eval do
  desc "Retrieval recall@k and MRR per mode and language. SET=manual|cards KIND=docs SAVE=1 DETAILS=1"
  task retrieval: :environment do
    set = ENV.fetch("SET", "manual")
    items = set == "cards" ? RetrievalEval.from_cards : RetrievalEval.load(Rails.root.join("spec/evals/retrieval.yml"))
    abort "No questions in set #{set}" if items.empty?

    filters = { kind: ENV["KIND"].presence }.compact
    eval = RetrievalEval.new(items, filters:)
    table = retrieval_table(eval.report)
    settings = "set: #{set} (#{items.size}), filters: #{filters.presence || 'none'}, embeddings: #{Embeddings.model}, " \
               "chunks: #{Chunk.count}, hybrid: RRF k=#{HybridSearch::K}, #{HybridSearch::CANDIDATES} candidates"

    puts retrieval_details(eval) if ENV["DETAILS"]
    save_eval("Retrieval", settings, table)
  end

  desc "RAG answers: expected outcome, citations, groundedness (LLM judge), injection leaks. SAVE=1"
  task generation: :environment do
    warn_if_fake_llm
    eval = GenerationEval.new(GenerationEval.load(Rails.root.join("spec/evals/generation.yml")))
    eval.results.each do |r|
      marks = [ (r.expected? ? "ok" : "WRONG #{r.status}"), ("invalid #{r.invalid_citations.map { "S#{_1}" }.join(',')}" if r.invalid_citations.any?),
                ("claims #{Array(r.supported).count(true)}/#{r.claims.size}" if r.status == "answered"), ("LEAK" if r.leaked) ]
      puts "#{marks.compact.join(', ')}  [#{r.item.language}] #{r.item.question}"
    end
    save_eval("Generation", eval_settings, summary_table(eval.summary))
  end

  desc "LLM judge agreement with human scores (exact and ±1). SAVE=1"
  task grader: :environment do
    warn_if_fake_llm
    eval = GraderEval.new(GraderEval.load(Rails.root.join("spec/evals/grader.yml")))
    eval.disagreements.each do |r|
      puts "human #{r.item.human_score} judge #{r.judge_score || 'failed'}  #{r.item.answer.truncate(70)}", "  #{r.feedback}"
    end
    save_eval("Grader", eval_settings, summary_table(eval.summary))
  end

  def warn_if_fake_llm
    puts "WARNING: LLM stub in use, numbers are meaningless. Set ANTHROPIC_API_KEY.", "" if LlmClient.provider.model == LlmClient::FakeProvider::MODEL
  end

  def eval_settings = "llm: #{LlmClient.provider.model}, embeddings: #{Embeddings.model}, chunks: #{Chunk.count}"

  def summary_table(summary)
    [ "| metric | value |", "| --- | --- |", *summary.map { |key, value| "| #{key} | #{value.nil? ? '—' : value} |" } ].join("\n")
  end

  def save_eval(title, settings, table)
    puts "", settings, "", table
    return unless ENV["SAVE"]

    File.open(Rails.root.join("docs/eval_results.md"), "a") { _1.puts "", "## #{title}, #{Date.current}", "", settings, "", table }
    puts "", "Appended to docs/eval_results.md"
  end

  def retrieval_table(report)
    rows = report.map do |(mode, language), m|
      [ mode, language, m.count, *m.recall.values.map { format("%.2f", _1) }, format("%.2f", m.mrr) ]
    end
    header = [ "mode", "lang", "n", *RetrievalEval::KS.map { "R@#{_1}" }, "MRR" ]
    [ header, header.map { "---" }, *rows ].map { "| #{_1.join(' | ')} |" }.join("\n")
  end

  # Place of the first relevant chunk per mode for every question ("-" = not in the top 10)
  def retrieval_details(eval)
    eval.items.each_with_index.map do |item, i|
      places = RetrievalEval::MODES.map { |mode| "#{mode}:#{eval.places[mode][i] || '-'}" }
      "#{places.join(' ')}  [#{item.language}] #{item.question}"
    end
  end
end
