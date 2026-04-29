import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { interval: Number, url: String }

  connect() {
    console.log("[poll] connected", { url: this.urlValue, interval: this.intervalValue, frame: this.element.id })
    this.timer = setInterval(this.tick.bind(this), this.intervalValue || 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  tick() {
    if (document.hidden) return
    if (this.element.closest(".agent-detail")?.classList.contains("hidden")) return
    console.log("[poll] tick", this.element.id, "src=", this.element.src)
    if (this.element.src) {
      this.element.reload()
    } else {
      this.element.src = this.urlValue
    }
  }
}
