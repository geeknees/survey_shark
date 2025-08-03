import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['form', 'textarea', 'submit', 'counter', 'loading']

  connect() {
    this.updateCounter()
    this.updateSubmitButton()
    this.isSubmitting = false

    // Listen for response complete events
    this.responseCompleteHandler = () => {
      this.resetForm()
    }
    document.addEventListener(
      'chat:response-complete',
      this.responseCompleteHandler
    )
  }

  disconnect() {
    document.removeEventListener(
      'chat:response-complete',
      this.responseCompleteHandler
    )
  }

  textareaTargetConnected() {
    this.textareaTarget.addEventListener('input', () => {
      this.updateCounter()
      this.updateSubmitButton()
    })

    this.textareaTarget.addEventListener('keydown', (event) => {
      if (event.key === 'Enter' && !event.shiftKey) {
        event.preventDefault()
        if (this.canSubmit() && !this.isSubmitting) {
          this.showLoading()
          this.isSubmitting = true
          this.formTarget.requestSubmit()
        }
      }
    })
  }

  submitForm() {
    if (this.isSubmitting || !this.canSubmit()) return

    this.showLoading()
    this.isSubmitting = true
    this.formTarget.requestSubmit()
  }

  handleSubmit(event) {
    if (this.isSubmitting || !this.canSubmit()) {
      event.preventDefault()
      return
    }

    this.showLoading()
    this.isSubmitting = true
  }

  insertQuickReply(event) {
    const text = event.currentTarget.dataset.text
    this.textareaTarget.value = text
    this.updateCounter()
    this.updateSubmitButton()
    this.textareaTarget.focus()
  }

  showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove('hidden')
    }
    this.updateSubmitButton()
  }

  hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add('hidden')
    }
    this.isSubmitting = false
    this.updateSubmitButton()
  }

  // Called when new message is added to reset form
  resetForm() {
    this.textareaTarget.value = ''
    this.updateCounter()
    this.hideLoading()
  }

  updateCounter() {
    if (this.hasCounterTarget) {
      const length = this.textareaTarget.value.length
      this.counterTarget.textContent = length

      if (length > 450) {
        this.counterTarget.classList.add('text-red-500')
        this.counterTarget.classList.remove('text-gray-500')
      } else {
        this.counterTarget.classList.add('text-gray-500')
        this.counterTarget.classList.remove('text-red-500')
      }
    }
  }

  updateSubmitButton() {
    if (this.hasSubmitTarget) {
      const canSubmit = this.canSubmit() && !this.isSubmitting
      this.submitTarget.disabled = !canSubmit

      if (canSubmit) {
        this.submitTarget.classList.remove('opacity-50')
      } else {
        this.submitTarget.classList.add('opacity-50')
      }
    }
  }

  canSubmit() {
    const content = this.textareaTarget.value.trim()
    return content.length > 0 && content.length <= 500
  }
}
