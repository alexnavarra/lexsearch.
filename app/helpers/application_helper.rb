module ApplicationHelper
  # "с. 12" for a PDF chunk; links to that page of the original file when it is stored
  def chunk_pages(chunk)
    return unless chunk.pages

    label = "с. #{chunk.pages}"
    file = chunk.document.source_file
    return tag.span(label, class: "text-gray-500") unless file.attached?

    link_to label, "#{rails_blob_path(file, disposition: 'inline')}#page=#{chunk.page_from}",
            target: "_blank", rel: "noopener", class: "text-blue-700 hover:underline", data: { turbo: false }
  end
end
