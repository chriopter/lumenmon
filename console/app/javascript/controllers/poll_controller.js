import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { interval: Number, url: String }

  connect() {
    this.timer = setInterval(this.tick.bind(this), this.intervalValue || 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  tick() {
    if (document.hidden) return
    if (this.element.closest(".agent-detail")?.classList.contains("hidden")) return
    if (this.element.src) {
      this.element.reload()
    } else {
      this.element.src = this.urlValue
    }
  }
}
