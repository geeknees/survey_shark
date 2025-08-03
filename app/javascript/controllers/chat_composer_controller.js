import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['form', 'textarea', 'submit', 'counter', 'loading']

  connect() {
    this.updateCounter()
    this.updateSubmitButton()
    this.isSubmitting = false
    this.reconnectAttempts = 0
    this.maxReconnectAttempts = 5

    // Listen for response complete events
    this.responseCompleteHandler = () => {
      this.resetForm()
    }
    document.addEventListener(
      'chat:response-complete',
      this.responseCompleteHandler
    )

    // Listen for Turbo Stream connection events
    this.connectionLostHandler = () => {
      this.handleConnectionLoss()
    }
    this.connectionRestoredHandler = () => {
      this.handleConnectionRestored()
    }

    document.addEventListener(
      'turbo:before-stream-render',
      this.connectionRestoredHandler
    )

    // Set up periodic connection check
    this.connectionCheckInterval = setInterval(() => {
      this.checkConnection()
    }, 30000) // Check every 30 seconds
  }

  disconnect() {
    document.removeEventListener(
      'chat:response-complete',
      this.responseCompleteHandler
    )
    document.removeEventListener(
      'turbo:before-stream-render',
      this.connectionRestoredHandler
    )

    if (this.connectionCheckInterval) {
      clearInterval(this.connectionCheckInterval)
    }
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

    // Prevent double submission with timestamp check
    const now = Date.now()
    if (this.lastSubmitTime && now - this.lastSubmitTime < 1000) {
      console.warn('Preventing duplicate submission')
      return
    }
    this.lastSubmitTime = now

    this.showLoading()
    this.isSubmitting = true

    // Set a timeout to reset submission state if something goes wrong
    this.submissionTimeout = setTimeout(() => {
      console.warn('Submission timeout, resetting form state')
      this.resetForm()
    }, 30000) // 30 second timeout

    this.formTarget.requestSubmit()
  }

  handleSubmit(event) {
    if (this.isSubmitting || !this.canSubmit()) {
      event.preventDefault()
      return
    }

    // Additional check for connection before submitting
    if (!this.isConnected()) {
      event.preventDefault()
      this.showConnectionError()
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

    // Clear the submission timeout if it exists
    if (this.submissionTimeout) {
      clearTimeout(this.submissionTimeout)
      this.submissionTimeout = null
    }
  }

  handleConnectionLoss() {
    console.warn('Connection lost, disabling form')
    this.showConnectionError()
  }

  handleConnectionRestored() {
    console.log('Connection restored')
    this.hideConnectionError()
    this.reconnectAttempts = 0
  }

  checkConnection() {
    // Simple check by attempting to access ActionCable connection
    if (
      window.App &&
      window.App.cable &&
      window.App.cable.connection.isOpen()
    ) {
      this.handleConnectionRestored()
    } else if (this.reconnectAttempts < this.maxReconnectAttempts) {
      this.attemptReconnection()
    }
  }

  attemptReconnection() {
    this.reconnectAttempts++
    console.log(
      `Attempting reconnection ${this.reconnectAttempts}/${this.maxReconnectAttempts}`
    )

    // Force reconnection if ActionCable is available
    if (window.App && window.App.cable) {
      window.App.cable.connection.open()
    }
  }

  isConnected() {
    return (
      window.App && window.App.cable && window.App.cable.connection.isOpen()
    )
  }

  showConnectionError() {
    // Add a visual indicator for connection issues
    if (this.hasSubmitTarget) {
      this.submitTarget.textContent = '接続を確認中...'
      this.submitTarget.disabled = true
    }
  }

  hideConnectionError() {
    // Restore normal submit button state
    if (this.hasSubmitTarget) {
      this.submitTarget.textContent = '送信'
      this.updateSubmitButton()
    }
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
