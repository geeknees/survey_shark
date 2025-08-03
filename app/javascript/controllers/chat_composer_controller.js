import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "textarea", "submit", "counter"]

  connect() {
    this.updateCounter()
    this.updateSubmitButton()
  }

  textareaTargetConnected() {
    this.textareaTarget.addEventListener("input", () => {
      this.updateCounter()
      this.updateSubmitButton()
    })
    
    this.textareaTarget.addEventListener("keydown", (event) => {
      if (event.key === "Enter" && !event.shiftKey) {
        event.preventDefault()
        if (this.canSubmit()) {
          this.formTarget.requestSubmit()
        }
      }
    })
  }

  insertQuickReply(event) {
    const text = event.currentTarget.dataset.text
    this.textareaTarget.value = text
    this.updateCounter()
    this.updateSubmitButton()
    this.textareaTarget.focus()
  }

  updateCounter() {
    if (this.hasCounterTarget) {
      const length = this.textareaTarget.value.length
      this.counterTarget.textContent = length
      
      if (length > 450) {
        this.counterTarget.classList.add("text-red-500")
        this.counterTarget.classList.remove("text-gray-500")
      } else {
        this.counterTarget.classList.add("text-gray-500")
        this.counterTarget.classList.remove("text-red-500")
      }
    }
  }

  updateSubmitButton() {
    if (this.hasSubmitTarget) {
      const canSubmit = this.canSubmit()
      this.submitTarget.disabled = !canSubmit
      
      if (canSubmit) {
        this.submitTarget.classList.remove("opacity-50")
      } else {
        this.submitTarget.classList.add("opacity-50")
      }
    }
  }

  canSubmit() {
    const content = this.textareaTarget.value.trim()
    return content.length > 0 && content.length <= 500
  }
}