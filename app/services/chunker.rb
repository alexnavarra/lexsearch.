# Splits a normalized Markdown body (see MarkdownNormalizer) into chunks along its structure:
# sections by # / ## / ### headings, long sections by paragraphs, overlong paragraphs by sentences.
# A fenced code block is never split: if it alone exceeds the limit, it becomes its own chunk.
class Chunker
  Piece = Data.define(:heading, :section_ref, :content, :token_count)

  MAX_TOKENS = 800
  HEADING = /\A(\#{1,3})\s+(.+?)(?:\s+#+)?\s*\z/
  FENCE = /\A\s*(```|~~~)/
  # Zero-width split point after a sentence end or a line break; separators stay with the text
  SENTENCE_BREAK = /(?<=[.!?…]\s|\n)/

  # Rough estimate: ~4 characters per token for Latin text, ~3 for Cyrillic
  def self.estimate_tokens(text)
    cyrillic = text.scan(/\p{Cyrillic}/).size
    ((text.length - cyrillic) / 4.0 + cyrillic / 3.0).ceil
  end

  def initialize(body, title:, max_tokens: MAX_TOKENS)
    @body, @title, @max_tokens = body.to_s, title.to_s, max_tokens
  end

  def call
    sections.flat_map do |path, lines|
      section_ref = [ @title, *path ].join(" > ")
      pack(blocks(lines)).map do |content|
        Piece.new(heading: path.last, section_ref:, content:, token_count: tokens(content))
      end
    end
  end

  private

  def tokens(text) = self.class.estimate_tokens(text)

  def code?(block) = block.match?(FENCE)

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
        result << [ breadcrumb(stack.map(&:last)), [] ]
      else
        result.last.last << line
      end
    end

    result
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
    return [] if code?(previous) || code?(block)

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
