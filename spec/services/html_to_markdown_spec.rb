require "rails_helper"

RSpec.describe HtmlToMarkdown do
  subject(:markdown) { described_class.new(file_fixture("pg_docs_page.html").read).call }

  it "takes only the main content and drops navigation, toc, scripts and anchors" do
    expect(markdown).not_to include("Search the docs", "Prev", "Next:", "var x", "11.2.1. B-Tree\n\n11.2.1")
    expect(markdown).not_to match(/Index Types #/)
  end

  it "shifts headings so the top one becomes #" do
    expect(markdown).to include("# 11.2. Index Types\n", "## 11.2.1. B-Tree\n")
  end

  it "keeps inline code and flattens links and emphasis to text" do
    expect(markdown).to include("By default, the `CREATE INDEX` command creates B-tree indexes.")
  end

  it "turns pre into a fenced code block" do
    expect(markdown).to include("```\nCREATE INDEX name ON table USING HASH (column);\n```")
  end

  it "converts lists, definition lists and tables" do
    expect(markdown).to include("- equality\n- range")
    expect(markdown).to include("**dirty read**\n\nReads uncommitted data.")
    expect(markdown).to include("| Level | Dirty Read |\n| Read committed | Not possible |")
  end

  it "falls back to body and returns empty string for empty input" do
    expect(described_class.new("<p>Hello</p>").call).to eq("Hello\n")
    expect(described_class.new("").call).to eq("")
  end
end
