import { Controller } from "@hotwired/stimulus"

// File picker with drag and drop: checks type and size before upload, fills the title from the
// file name, hides the paste-text fields while a file is chosen, locks the button while uploading
export default class extends Controller {
  static targets = ["input", "zone", "prompt", "chosen", "name", "size", "error", "title", "pasted", "submit"]
  static values = { maxBytes: Number, extensions: Array }

  connect() {
    this.depth = 0
  }

  dragenter(event) {
    event.preventDefault()
    this.depth++
    this.zoneTarget.classList.add("border-gray-900", "bg-gray-100")
  }

  dragover(event) {
    event.preventDefault()
  }

  dragleave() {
    if (--this.depth === 0) this.unhighlight()
  }

  drop(event) {
    event.preventDefault()
    this.depth = 0
    this.unhighlight()
    if (!event.dataTransfer.files.length) return

    this.inputTarget.files = event.dataTransfer.files
    this.choose()
  }

  choose() {
    const file = this.inputTarget.files[0]
    if (!file) return this.clear()

    const error = this.problem(file)
    if (error) {
      this.clear()
      return this.showError(error)
    }

    this.showError(null)
    this.nameTarget.textContent = file.name
    this.sizeTarget.textContent = this.humanSize(file.size)
    this.toggle(true)
    if (!this.titleTarget.value.trim()) this.titleTarget.value = file.name.replace(/\.[^.]+$/, "").replace(/[_]+/g, " ").trim()
  }

  clear() {
    this.inputTarget.value = ""
    this.toggle(false)
  }

  submit() {
    // Disabled on the next tick, so the click still submits the form
    setTimeout(() => {
      this.submitTarget.disabled = true
      this.submitTarget.value = this.inputTarget.files.length ? "Загружаю файл…" : "Сохраняю…"
    })
  }

  problem(file) {
    const extension = file.name.includes(".") ? file.name.split(".").pop().toLowerCase() : ""
    if (!this.extensionsValue.includes(extension)) return `Формат .${extension || "?"} не поддерживается: нужен ${this.extensionsValue.map((e) => "." + e).join(", ")}`
    if (file.size > this.maxBytesValue) return `Файл ${this.humanSize(file.size)}, а можно не больше ${this.humanSize(this.maxBytesValue)}`
    if (file.size === 0) return "Файл пустой"
  }

  toggle(chosen) {
    this.promptTarget.hidden = chosen
    this.chosenTarget.hidden = !chosen
    this.pastedTargets.forEach((element) => (element.hidden = chosen))
  }

  showError(message) {
    this.errorTarget.textContent = message || ""
    this.errorTarget.hidden = !message
  }

  unhighlight() {
    this.zoneTarget.classList.remove("border-gray-900", "bg-gray-100")
  }

  humanSize(bytes) {
    if (bytes < 1024) return `${bytes} Б`
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} КБ`
    return `${(bytes / 1024 / 1024).toFixed(1)} МБ`
  }
}
