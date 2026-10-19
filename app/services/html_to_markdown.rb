# Converts an HTML page to Markdown, keeping only what matters for search:
# headings, paragraphs, lists, tables and code blocks. Links become plain text.
class HtmlToMarkdown
  CONTENT_SELECTORS = [ "#docContent", "main", "article", "body" ].freeze # #docContent: PostgreSQL docs
  NOISE = "script, style, nav, header, footer, .navheader, .navfooter, .toc, a.id_link"
  BLOCKS = %w[p div section ul ol li dl dt dd table pre blockquote h1 h2 h3 h4 h5 h6].freeze

  def initialize(html)
    @doc = Nokogiri::HTML(html.to_s)
  end

  def call
    root = CONTENT_SELECTORS.lazy.map { @doc.at_css(_1) }.find(&:itself)
    return "" unless root

    root.css(NOISE).remove
    @heading_shift = root.css("h1, h2, h3, h4, h5, h6").map { _1.name[1].to_i }.min.to_i - 1

    MarkdownNormalizer.new(blocks(root).join("\n\n")).call.then { _1.strip.empty? ? "" : _1 }
  end

  private

  # Consecutive inline nodes (text, code, a, em...) form one paragraph
  def blocks(node)
    node.children.chunk_while { inline?(_1) && inline?(_2) }.flat_map { |group|
      inline?(group.first) ? [ inline(group) ] : block(group.first)
    }.compact_blank
  end

  def inline?(node) = !node.element? || BLOCKS.exclude?(node.name)

  def block(node)
    case node.name
    when /\Ah([1-6])\z/ then [ "#" * [ $1.to_i - @heading_shift, 1 ].max + " " + inline(node) ]
    when "p" then [ inline(node) ]
    when "pre" then [ "```\n#{node.text.strip}\n```" ]
    when "ul", "ol" then [ list(node) ]
    when "dl" then [ definition_list(node) ]
    when "table" then [ table(node) ]
    when "blockquote" then [ blocks(node).map { "> #{_1}" }.join("\n>\n") ]
    else blocks(node) # div, section: just containers
    end
  end

  # Accepts a node (uses its children) or a list of sibling nodes
  def inline(nodes)
    nodes = nodes.children if nodes.is_a?(Nokogiri::XML::Node)
    text = nodes.map { |child|
      next child.text.gsub(/\s+/, " ") if child.text?
      next "" unless child.element?
      next "`#{child.text.squish}`" if child.name == "code"
      next "\n" if child.name == "br"

      inline(child)
    }.join
    text.gsub(/[[:blank:]]+/, " ").gsub(/ *\n */, "\n").strip
  end

  def list(node)
    marker = node.name == "ol" ? "1." : "-"
    node.element_children.select { _1.name == "li" }.map { |li| "#{marker} #{blocks(li).join(' ')}" }.join("\n")
  end

  def definition_list(node)
    node.element_children.select { _1.name.in?(%w[dt dd]) }.map { |item|
      item.name == "dt" ? "**#{inline(item)}**" : blocks(item).join("\n\n")
    }.join("\n\n")
  end

  # Tables stay as simple pipe rows: enough for search, no alignment
  def table(node)
    node.css("tr").map { |tr| "| " + tr.css("th, td").map { inline(_1) }.join(" | ") + " |" }.join("\n")
  end
end
