# Turns a PDF into the Markdown the Chunker expects, with a <!-- page N --> marker before each page's text.
# PDF has no paragraphs or headings, only positioned glyphs, so they are rebuilt here:
# - running headers/footers and page numbers are removed (lines repeated on many pages);
# - wrapped lines are joined into paragraphs, "replica-\ntion" becomes "replication";
# - indented runs become code blocks, bullets become list items;
# - headings come from the PDF outline (bookmarks), or from numbering ("Chapter 3", "3.2 Title") without one.
class PdfExtractor
  class Error < StandardError; end

  # Less text than this per page on average means a scan: there is no text layer, only images (needs OCR)
  MIN_CHARS_PER_PAGE = 50
  # How many lines at the top and bottom of a page may be a header or footer
  EDGE_LINES = 3
  BULLET = /\A([•●▪◦‣∙·*–-]|\d{1,2}[.)])\s+(\S.*)\z/
  PAGE_NUMBER = /\A(\d{1,4}|[ivxlcdm]{1,7})\z/i
  TERMINAL = /[.!?:;)"”»]\z/
  NUMBERED_HEADINGS = [
    [ 1, /\A(Chapter|Part|Глава|Часть)\s+\d+\b.{0,70}\z/i ],
    [ 3, /\A\d+\.\d+\.\d+\.?\s+\p{Lu}[^.]{0,70}\z/ ],
    [ 2, /\A\d+\.\d+\.?\s+\p{Lu}[^.]{0,70}\z/ ]
  ].freeze

  Block = Struct.new(:type, :page, :lines, :level)

  def initialize(data)
    @data = data.to_s.b
  end

  # Full extraction: slow on a book (~50 ms per page), so IndexDocumentJob runs it
  def call
    pages = with_reader { |reader| reader.pages.map { page_lines(_1) } }
    check_text_layer(pages)
    @headings = with_reader { outline_headings(_1) }
    render(blocks(strip_furniture(pages)))
  end

  # Quick check at upload time: opens, is not encrypted or a scan. Returns the first pages' text (for language detection)
  def probe(pages: 10)
    sample = with_reader { |reader| reader.pages.first(pages).map { page_lines(_1) } }
    check_text_layer(sample)
    sample.flatten.join("\n")
  end

  private

  def with_reader
    @reader ||= PDF::Reader.new(StringIO.new(@data))
    yield @reader
  rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError, PDF::Reader::EncryptedPDFError => e
    raise Error, "#{e.class.name.demodulize}: #{e.message}"
  end

  def check_text_layer(pages)
    raise Error, "no pages" if pages.empty?
    return if pages.sum { |lines| lines.sum(&:length) } >= MIN_CHARS_PER_PAGE * pages.size

    raise Error, "almost no text: probably a scan, which needs OCR"
  end

  # One page's lines; ligatures and odd spaces normalized ("ﬁ" -> "fi"), a broken page yields nothing
  def page_lines(page)
    page.text.unicode_normalize(:nfkc).lines(chomp: true).map(&:rstrip)
  rescue StandardError
    []
  end

  # Drops lines near the page edges that repeat on many pages (digits ignored) or are bare page numbers
  def strip_furniture(pages)
    edges = pages.map { |lines| edge_indexes(lines) }
    counts = Hash.new(0)
    pages.zip(edges).each { |lines, indexes| indexes.map { furniture_key(lines[_1]) }.uniq.each { counts[_1] += 1 } }
    threshold = [ 3, (pages.size * 0.3).ceil ].max

    pages.zip(edges).map do |lines, indexes|
      drop = indexes.select { |i| lines[i].strip.match?(PAGE_NUMBER) || counts[furniture_key(lines[i])] >= threshold }
      lines.reject.with_index { |_, i| drop.include?(i) }
    end
  end

  def edge_indexes(lines)
    filled = lines.each_index.reject { lines[_1].strip.empty? }
    (filled.first(EDGE_LINES) + filled.last(EDGE_LINES)).uniq
  end

  def furniture_key(line) = line.strip.gsub(/\d+/, "#").downcase

  def blocks(pages)
    @blocks = []
    pages.each.with_index(1) do |lines, page|
      base = base_indent(lines)
      blank = true # a page break separates like a blank line
      lines.each do |line|
        if line.strip.empty?
          blank = true
          current.lines << "" if current&.type == :code
        else
          add_line(line, page, base, blank)
          blank = false
        end
      end
    end
    @blocks
  end

  def current = @blocks.last

  def add_line(line, page, base, blank)
    text = line.strip
    indent = line[/\A */].size

    if (level = heading_level(text, page))
      @blocks << Block.new(:heading, page, [ text ], level)
    elsif current&.type == :code && indent >= base + 2
      current.lines << line # "* main" in command output is not a list item
    elsif (bullet = text.match(BULLET))
      marker = bullet[1].match?(/\d/) ? bullet[1].sub(")", ".") : "-"
      @blocks << Block.new(:list, page, [ "#{marker} #{bullet[2]}" ])
    elsif current&.type == :list && !blank && indent > base
      current.lines << text
    elsif indent >= base + 2
      current&.type == :code ? current.lines << line : @blocks << Block.new(:code, page, [ line ])
    elsif current&.type == :para && continues?(current.lines.last, text, blank)
      current.lines << text
    else
      @blocks << Block.new(:para, page, [ text ])
    end
  end

  # Smallest indent: body text; code and notes are indented further (a page may hold more code than text)
  def base_indent(lines)
    lines.reject { _1.strip.empty? }.map { _1[/\A */].size }.min || 0
  end

  # Layout gaps appear inside sentences too, so a blank line ends a paragraph only after a sentence end
  def continues?(previous, text, blank)
    return true unless blank

    text.match?(/\A\p{Ll}/) || (!previous.match?(TERMINAL) && previous.length >= 50)
  end

  def heading_level(text, page)
    if @headings.any?
      level = @headings.dig(page, normalize(text)) or return
      @headings[page].delete(normalize(text)) # each bookmark marks one line
      level
    else
      NUMBERED_HEADINGS.find { |_, pattern| text.match?(pattern) }&.first
    end
  end

  def render(blocks)
    page = nil
    out = blocks.flat_map do |block|
      marker = Chunker.page_marker(block.page) if block.page != page
      page = block.page
      [ marker, *render_block(block) ].compact
    end
    MarkdownNormalizer.new(out.join("\n\n")).call
  end

  def render_block(block)
    case block.type
    when :heading then "#{'#' * block.level} #{block.lines.first.squish}"
    when :code then render_code(block.lines)
    else escape(join_lines(block.lines))
    end
  end

  # Indented runs hold code and also notes or quotes: runs of prose become paragraphs, the rest stays fenced
  def render_code(lines)
    runs = lines.chunk_while { |a, b| a.strip.empty? == b.strip.empty? }.reject { _1.first.strip.empty? }
    runs.slice_when { |a, b| prose?(a) || prose?(b) }.map do |group|
      next escape(join_lines(group.first.map(&:strip))) if prose?(group.first)

      "```\n#{dedent(group.each_with_index.flat_map { |run, i| i.zero? ? run : [ "", *run ] })}\n```"
    end
  end

  # Indented text is also used for notes and quotes: long lines of words, no shell prompt or code punctuation
  def prose?(lines)
    filled = lines.map(&:strip).compact_blank
    return false if filled.any? { _1.match?(/\A[$#>]\s|[{};=]|\A\S+\(/) }

    filled.sum { _1.split.size } >= 7 * filled.size
  end

  # "replica-" + "tion" -> "replication"; other lines joined with a space
  def join_lines(lines)
    lines.reduce do |text, line|
      text.match?(/\p{L}-\z/) && line.match?(/\A\p{Ll}/) ? text.delete_suffix("-") + line : "#{text} #{line}"
    end.squish
  end

  def dedent(lines)
    lines = lines.dup
    lines.pop while lines.last&.strip&.empty?
    margin = lines.reject { _1.strip.empty? }.map { _1[/\A */].size }.min || 0
    lines.map { _1[margin..].to_s }.join("\n")
  end

  # A paragraph that starts like "# foo" must not turn into a heading
  def escape(text) = text.match?(/\A#+\s/) ? "\\#{text}" : text

  def normalize(text) = text.unicode_normalize(:nfkc).downcase.gsub(/[^\p{L}\p{N}]+/, " ").strip

  # { page => { normalized title => heading level 1..3 } } from the PDF bookmarks
  def outline_headings(reader)
    objects = reader.objects
    catalog = objects.deref(objects.trailer[:Root])
    root = objects.deref(catalog[:Outlines]) if catalog
    return {} unless root

    pages = objects.page_references.each_with_index.to_h { |ref, i| [ [ ref.id, ref.gen ], i + 1 ] }
    headings = Hash.new { |hash, page| hash[page] = {} }
    walk_outline(objects, root[:First], 1, catalog, pages, headings, Set.new)
    headings.default_proc = nil
    headings
  rescue StandardError
    {} # a broken outline is not worth failing the import: fall back to numbered headings
  end

  def walk_outline(objects, item_ref, depth, catalog, pages, headings, seen)
    while item_ref && seen.add?(item_ref.respond_to?(:id) ? [ item_ref.id, item_ref.gen ] : item_ref.object_id) && seen.size < 10_000
      item = objects.deref(item_ref)
      page = destination_page(objects, item, catalog, pages)
      title = normalize(decode(item[:Title]))
      headings[page][title] ||= [ depth, 3 ].min if page && title.present?
      walk_outline(objects, item[:First], depth + 1, catalog, pages, headings, seen) if item[:First]
      item_ref = item[:Next]
    end
  end

  def destination_page(objects, item, catalog, pages)
    dest = item[:Dest] || objects.deref(item[:A])&.then { objects.deref(_1)[:D] }
    dest = named_destinations(objects, catalog)[dest.to_s] if dest.is_a?(String) || dest.is_a?(Symbol)
    dest = objects.deref(dest)
    dest = objects.deref(dest[:D]) if dest.is_a?(Hash)
    target = dest.first if dest.is_a?(Array)
    target.is_a?(PDF::Reader::Reference) ? pages[[ target.id, target.gen ]] : nil
  end

  # Old style /Dests dictionary plus the /Names /Dests name tree
  def named_destinations(objects, catalog)
    @named_destinations ||= begin
      names = objects.deref(catalog[:Dests]).to_h.transform_keys(&:to_s)
      tree = objects.deref(objects.deref(catalog[:Names])&.dig(:Dests))
      collect_names(objects, tree, names, Set.new)
      names
    end
  end

  def collect_names(objects, node, names, seen)
    return unless node.is_a?(Hash) && seen.add?(node.object_id)

    Array(objects.deref(node[:Names])).each_slice(2) { |key, value| names[key.to_s] = value }
    Array(objects.deref(node[:Kids])).each { collect_names(objects, objects.deref(_1), names, seen) }
  end

  # Outline titles are UTF-16BE with a BOM or PDFDocEncoding (close enough to Latin-1)
  def decode(title)
    string = title.to_s.b
    return string[2..].force_encoding("UTF-16BE").encode("UTF-8", invalid: :replace, undef: :replace) if string.start_with?("\xFE\xFF".b)

    string.force_encoding("ISO-8859-1").encode("UTF-8")
  end
end
