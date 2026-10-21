module QuestionsHelper
  # Escapes the answer, then turns [S2] into a link that opens source S2; ids we never sent are red
  def render_answer(question)
    valid = question.citations.fetch("cited", [])
    html = ERB::Util.html_escape(question.answer.to_s).gsub(RagAnswerer::CITATION) do
      id = Regexp.last_match(1).to_i
      if valid.include?(id)
        %(<a href="#source-S#{id}" data-source="source-S#{id}" class="font-medium text-blue-700 hover:underline">[S#{id}]</a>)
      else
        %(<span class="rounded bg-red-100 px-1 text-red-700" title="Такого источника не было">[S#{id}]</span>)
      end
    end
    safe_join(html.split(/\n{2,}/).map { tag.p(_1.gsub("\n", "<br>").html_safe, class: "mb-2") }) # rubocop:disable Rails/OutputSafety
  end
end
