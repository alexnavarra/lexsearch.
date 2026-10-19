require "rails_helper"

RSpec.describe MarkdownNormalizer do
  def normalize(text) = described_class.new(text).call

  it "turns setext headings into ATX headings" do
    text = "Title\n=====\n\nIntro\n\nSection\n-------\n\nBody"

    expect(normalize(text)).to eq("# Title\n\nIntro\n\n## Section\n\nBody\n")
  end

  it "keeps a dash line after a blank line as a horizontal rule" do
    expect(normalize("Intro\n\n-----\n\nNext")).to eq("Intro\n\n-----\n\nNext\n")
  end

  it "does not treat list items as setext headings" do
    expect(normalize("- item\n---")).to eq("- item\n---\n")
  end

  it "leaves code blocks untouched" do
    text = "```\nvalue\n-----\n# comment\n```"

    expect(normalize(text)).to eq("#{text}\n")
  end

  it "normalizes line endings, trailing spaces and blank lines" do
    expect(normalize("a  \r\nb\r\n\r\n\r\n\r\nc")).to eq("a\nb\n\nc\n")
  end
end
