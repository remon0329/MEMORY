import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results"]
  static values = { url: String }

  connect() {
    this.inputTarget.addEventListener("input", this.onInput.bind(this))
  }

  async onInput(event) {
    const query = this.inputTarget.value
    if (query.length < 1) return

    const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`)
    const results = await response.json()

    this.resultsTarget.innerHTML = results.map(title =>
      `<li class="p-2 cursor-pointer hover:bg-gray-100">${title}</li>`
    ).join("")
  }
}
