import { Controller } from "@hotwired/stimulus"

// Clicking a [S2] citation opens the matching <details> source; the link itself scrolls to it
export default class extends Controller {
  open(event) {
    const link = event.target.closest("a[data-source]")
    if (!link) return

    const source = document.getElementById(link.dataset.source)
    if (source) source.open = true
  }
}
