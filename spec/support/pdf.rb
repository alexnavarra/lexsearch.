require "prawn"
Prawn::Fonts::AFM.hide_m17n_warning = true

# Small PDFs built in code: real files for PdfExtractor without binary fixtures in git
module PdfHelpers
  # A 3-page "book": running header, page-number footer, a word hyphenated across lines,
  # a paragraph that continues on the next page, a bullet list, an indented code block
  def book_pdf(outline: true)
    Prawn::Document.new(margin: 50) do |pdf|
      pdf.repeat(:all) { pdf.draw_text "Tiny Git Book", at: [ 0, pdf.bounds.top + 20 ], size: 9 }
      pdf.text "Getting Started", size: 18
      pdf.text "Git stores snapshots of the project. Every commit records the whole tree, and branches are cheap to create and switch between."
      pdf.text "The first replica-\ntion of a repository is called a clone."
      pdf.move_down 10
      pdf.text "• Speed"
      pdf.text "• Simple design"
      pdf.start_new_page
      pdf.text "Installing Git", size: 18
      pdf.text "Install Git with your package manager and check the version:"
      pdf.indent(30) { pdf.text "$ git --version", font: "Courier" }
      pdf.indent(30) { pdf.text "* main\nfeature", font: "Courier" }
      pdf.move_down 20
      pdf.indent(30) { pdf.text "This book was written for Git version 2, and most of the commands work in older versions too." }
      pdf.text "Most distributions ship a recent enough version, so building from source is rarely"
      pdf.start_new_page
      pdf.text "needed today."
      pdf.text "1.2 Configuring Identity", size: 14
      pdf.text "Set your name and email before the first commit, because every commit uses them."
      pdf.number_pages "<page>", at: [ pdf.bounds.right - 20, -10 ], size: 9
      if outline
        pdf.outline.define do
          section("Getting Started", destination: 1) do
            page destination: 2, title: "Installing Git"
            page destination: 3, title: "1.2 Configuring Identity"
          end
        end
      end
    end.render
  end
end

RSpec.configure { _1.include PdfHelpers }
