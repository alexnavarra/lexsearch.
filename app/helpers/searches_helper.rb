module SearchesHelper
  # Escape the document text first, then turn FulltextSearch markers into <mark>: document HTML never renders
  def highlight_snippet(snippet)
    ERB::Util.html_escape(snippet)
             .gsub(FulltextSearch::MARK_START, '<mark class="bg-yellow-200">')
             .gsub(FulltextSearch::MARK_STOP, "</mark>")
             .html_safe
  end
end
