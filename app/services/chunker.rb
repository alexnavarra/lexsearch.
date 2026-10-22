# Splits a normalized Markdown body (see MarkdownNormalizer) into chunks along its structure:
# sections by # / ## / ### headings, long sections by paragraphs, overlong paragraphs by sentences.
# A fenced code block is never split: if it alone exceeds the limit, it becomes its own chunk.
# Page markers (<!-- page N -->, from PdfExtractor) are dropped from the text and become page_from / page_to.
class Chunker
  Piece = Data.define(:heading, :section_ref, :content, :token_count, :page_from, :page_to)

  MAX_TOKENS = 800
  HEADING = /\A(\#{1,3})\s+(.+?)(?:\s+#+)?\s*\z/
  FENCE = /\A\s*(```|~~~)/
  # Zero-width split point after a sentence end or a line break; separators stay with the text
  SENTENCE_BREAK = /(?<=[.!?…]\s|\n)/
  PAGE = /\A<!-- page (\d+) -->\z/
  # A marker is always a block of its own, so it sits between "\n\n" or at an edge of the chunk
  PAGE_BLOCK = /(?:\A|\n\n)<!-- page \d+ -->(?=\n\n|\z)/

  def self.page_marker(number) = "<!-- page #{number} -->"

  # Rough estimate: ~4 characters per token for Latin text, ~3 for Cyrillic
  def self.estimate_tokens(text)
    cyrillic = text.scan(/\p{Cyrillic}/).size
    ((text.length - cyrillic) / 4.0 + cyrillic / 3.0).ceil
  end

  def initialize(body, title:, max_tokens: MAX_TOKENS)
    @body, @title, @max_tokens = body.to_s, title.to_s, max_tokens
  end

  def call
    page = nil # last page marker seen, in document order
    sections.flat_map do |path, lines|
      section_ref = [ @title, *path ].join(" > ")
      pack(blocks(lines)).filter_map do |content|
        markers = content.scan(/<!-- page (\d+) -->/).flatten.map(&:to_i)
        page_from = content.match?(/\A<!-- page \d+ -->/) ? markers.first : page
        page = markers.last || page
        text = content.gsub(PAGE_BLOCK, "").strip
        next if text.empty?

        Piece.new(heading: path.last, section_ref:, content: text, token_count: tokens(text), page_from:, page_to: page)
      end
    end
  end

  private

  def tokens(text) = self.class.estimate_tokens(text)

  def code?(block) = block.match?(FENCE)

  def page?(block) = block.match?(PAGE)

  # [[heading path, body lines], ...]; text before the first heading gets an empty path
  def sections
    result = [ [ [], [] ] ]
    stack = [] # [[level, heading], ...]
    in_code = false

    @body.each_line(chomp: true) do |line|
      in_code = !in_code if line.match?(FENCE)
      match = line.match(HEADING) unless in_code

      if match
        level = match[1].size
        stack = stack.take_while { |(lvl, _)| lvl < level } << [ level, clean_heading(match[2]) ]
        result << [ breadcrumb(stack.map(&:last)), trailing_pages(result.last.last) ]
      else
        result.last.last << line
      end
    end

    result
  end

  # A page marker right before a heading belongs to the new section, not to the end of the old one
  def trailing_pages(lines)
    moved = []
    moved.unshift(lines.pop) while lines.any? && (lines.last.strip.empty? || page?(lines.last))
    moved.select { page?(_1) }
  end

  # The top heading usually repeats the document title, fully or in part
  def breadcrumb(path)
    top, title = path.first&.downcase, @title.downcase
    top && (title.include?(top) || top.include?(title)) ? path.drop(1) : path
  end

  def clean_heading(text)
    text.gsub(/\[([^\]]*)\]\([^)]*\)/, '\1').delete("`*").strip
  end

  # Paragraphs separated by blank lines; a fenced code block is one block, blank lines included
  def blocks(lines)
    blocks = []
    current = []
    in_code = false
    flush = -> { blocks << current.join("\n") if current.any?; current = [] }

    lines.each do |line|
      if line.match?(FENCE)
        flush.call unless in_code
        current << line
        in_code = !in_code
        flush.call unless in_code
      elsif line.strip.empty? && !in_code
        flush.call
      elsif page?(line) && !in_code
        flush.call
        blocks << line
      else
        current << line
      end
    end
    flush.call

    blocks
  end

  # Greedily packs blocks into chunks; a new chunk starts with the last sentence of the previous one
  def pack(blocks)
    chunks = []
    current = []

    blocks.flat_map { fit(_1) }.each do |block|
      if current.empty? || tokens([ *current, block ].join("\n\n")) <= @max_tokens
        current << block
      else
        chunks << current.join("\n\n")
        current = [ *overlap(current.last, block), block ]
      end
    end

    chunks << current.join("\n\n") if current.any?
    chunks
  end

  def overlap(previous, block)
    return [] if code?(previous) || code?(block) || page?(previous) || page?(block)

    sentence = sentences(previous).last.strip
    tokens("#{sentence}\n\n#{block}") <= @max_tokens ? [ sentence ] : []
  end

  # A paragraph over the limit is cut into runs of whole sentences
  def fit(block)
    return [ block ] if code?(block) || tokens(block) <= @max_tokens

    sentences(block).each_with_object([ +"" ]) do |sentence, parts|
      parts << +"" if parts.last.present? && tokens(parts.last + sentence) > @max_tokens
      parts.last << sentence
    end.map(&:strip)
  end

  def sentences(text) = text.split(SENTENCE_BREAK)
end
