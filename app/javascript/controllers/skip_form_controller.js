import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['submit', 'loading']

  connect() {
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

  handleSubmit(event) {
    if (this.isSubmitting) {
      event.preventDefault()
      return
    }

    this.showLoading()
    this.isSubmitting = true
  }

  showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove('hidden')
    }
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true
      this.submitTarget.classList.add('opacity-50')
    }
  }

  resetForm() {
    this.hideLoading()
  }

  hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add('hidden')
    }
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = false
      this.submitTarget.classList.remove('opacity-50')
    }
    this.isSubmitting = false
  }
}
