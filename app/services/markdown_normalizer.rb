# Brings Markdown to one dialect the Chunker relies on:
# ATX headings only (# / ##), \n line endings, no trailing spaces, at most one blank line.
class MarkdownNormalizer
  FENCE = /\A\s*(```|~~~)/
  SETEXT = { "=" => "#", "-" => "##" }.freeze

  def initialize(text)
    @text = text.to_s
  end

  def call
    lines = @text.gsub(/\r\n?/, "\n").split("\n", -1).map(&:rstrip)
    out = []
    in_code = false

    lines.each do |line|
      if line.match?(FENCE)
        in_code = !in_code
        out << line
      elsif !in_code && setext_underline?(line, out.last)
        out[-1] = "#{SETEXT[line[0]]} #{out.last.strip}"
      else
        out << line
      end
    end

    out.join("\n").gsub(/\n{3,}/, "\n\n").strip + "\n"
  end

  private

  # "Title\n=====" is a heading; "-----" after a blank line is a horizontal rule
  def setext_underline?(line, previous)
    line.match?(/\A(=+|-+)\z/) && previous.present? &&
      !previous.start_with?("#", "*", "-", ">", "|") && !previous.match?(/\A\d+\./)
  end
end
