import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  connect() {
    this.scrollToBottom()
    this.observeMutations()
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
  }

  observeMutations() {
    this.observer = new MutationObserver(() => this.scrollToBottom())
    this.observer.observe(this.element, { childList: true, subtree: true })
  }

  scrollToBottom() {
    try {
      this.element.scrollTop = this.element.scrollHeight
    } catch (_) {}
  }
}

