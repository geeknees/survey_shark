import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['form', 'textarea', 'submit', 'counter', 'loading']

  connect() {
    console.log('chat-composer controller connected')
    this.updateCounter()
    this.updateSubmitButton()
    this.isSubmitting = false

    // Listen for response complete events
    this.responseCompleteHandler = () => {
      console.log('chat:response-complete event received, resetting form')
      this.resetForm()
    }
    document.addEventListener(
      'chat:response-complete',
      this.responseCompleteHandler
    )

    // Set up observer to watch for form reset signals
    this.setupFormResetObserver()
  }

  disconnect() {
    document.removeEventListener(
      'chat:response-complete',
      this.responseCompleteHandler
    )

    if (this.formResetObserver) {
      this.formResetObserver.disconnect()
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
          console.log('Enter key pressed, submitting form')
          // Create a synthetic submit event to trigger handleSubmit
          const submitEvent = new Event('submit', {
            bubbles: true,
            cancelable: true
          })
          this.formTarget.dispatchEvent(submitEvent)
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
    }, 10000) // 10 second timeout (reduced from 30)

    this.formTarget.requestSubmit()
  }

  handleSubmit(event) {
    if (this.isSubmitting || !this.canSubmit()) {
      event.preventDefault()
      return
    }

    console.log('Form submitted, showing loading state')
    this.showLoading()
    this.isSubmitting = true

    // Fallback: Reset form after 15 seconds if no other reset occurs
    this.fallbackResetTimeout = setTimeout(() => {
      if (this.isSubmitting) {
        console.log('Fallback timeout reached, resetting form')
        this.resetForm()
      }
    }, 15000)
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
    console.log(
      'hideLoading called, hiding loading indicator and enabling submit button'
    )
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add('hidden')
    }
    this.isSubmitting = false
    this.updateSubmitButton()
  }

  // Called when new message is added to reset form
  resetForm() {
    console.log('resetForm called, hiding loading and clearing textarea')
    this.textareaTarget.value = ''
    this.updateCounter()
    this.hideLoading()

    // Clear the submission timeout if it exists
    if (this.submissionTimeout) {
      clearTimeout(this.submissionTimeout)
      this.submissionTimeout = null
    }

    // Clear the fallback reset timeout if it exists
    if (this.fallbackResetTimeout) {
      clearTimeout(this.fallbackResetTimeout)
      this.fallbackResetTimeout = null
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

  setupFormResetObserver() {
    // Watch for form reset signals in the messages container
    const messagesContainer = document.getElementById('messages')
    if (!messagesContainer) {
      console.warn(
        'Messages container not found, cannot set up form reset observer'
      )
      return
    }

    this.formResetObserver = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        mutation.addedNodes.forEach((node) => {
          if (node.nodeType === Node.ELEMENT_NODE) {
            // Check if this node or any child has the form-reset data attribute
            const resetElement =
              node.hasAttribute && node.hasAttribute('data-form-reset')
                ? node
                : node.querySelector &&
                  node.querySelector('[data-form-reset="true"]')

            if (resetElement && this.isSubmitting) {
              console.log('Form reset signal detected, resetting form')
              this.resetForm()
              resetElement.remove() // Clean up the signal element
            }
          }
        })
      })
    })

    this.formResetObserver.observe(messagesContainer, {
      childList: true,
      subtree: true
    })

    console.log('Form reset observer set up successfully')
  }
}
