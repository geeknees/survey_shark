import { Controller } from '@hotwired/stimulus'

// Debug helpers (enable by setting window.SURVEY_SHARK_DEBUG = true)
const dwarn = (...args) => {
  try {
    if (window && window.SURVEY_SHARK_DEBUG) console.warn(...args)
  } catch (_) {}
}

export default class extends Controller {
  static targets = ['submit', 'loading']

  connect() {
    this.isSubmitting = false
    this.setupFormResetObserver()
  }

  disconnect() {
    if (this.formResetObserver) {
      this.formResetObserver.disconnect()
    }
    if (this.fallbackResetTimeout) {
      clearTimeout(this.fallbackResetTimeout)
    }
  }

  async handleSubmit(event) {
    // Prevent navigation and post via fetch
    event.preventDefault()

    if (this.isSubmitting) {
      dwarn('Skip already submitting, ignoring')
      return
    }

    this.showLoading()
    this.isSubmitting = true

    // Fallback timeout
    this.fallbackResetTimeout = setTimeout(() => {
      if (this.isSubmitting) {
        dwarn('Skip fallback timeout reached, resetting form')
        this.resetForm()
      }
    }, 20000)

    try {
      const form = event.target
      const formData = new FormData(form)
      const token = document.querySelector('meta[name="csrf-token"]')?.content

      const res = await fetch(form.action, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': token || '',
          Accept: 'text/html',
          'X-Requested-With': 'XMLHttpRequest'
        },
        body: formData,
        credentials: 'same-origin'
      })

      if (!res.ok) {
        dwarn('Skip post returned non-OK status:', res.status)
        this.resetForm()
      }
      // Broadcasts will update UI and trigger reset
    } catch (e) {
      console.error('Skip post failed', e)
      this.resetForm()
    }
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
    if (this.fallbackResetTimeout) {
      clearTimeout(this.fallbackResetTimeout)
      this.fallbackResetTimeout = null
    }
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

  setupFormResetObserver() {
    const messagesContainer = document.getElementById('messages')
    if (!messagesContainer) {
      dwarn('Messages container not found for skip form reset observer')
      return
    }

    this.formResetObserver = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        mutation.addedNodes.forEach((node) => {
          if (node.nodeType === Node.ELEMENT_NODE) {
            const resetElement =
              node.hasAttribute && node.hasAttribute('data-form-reset')
                ? node
                : node.querySelector &&
                  node.querySelector('[data-form-reset="true"]')

            if (resetElement && this.isSubmitting) {
              this.resetForm()
              resetElement.remove()
            }
          }
        })
      })
    })

    this.formResetObserver.observe(messagesContainer, {
      childList: true,
      subtree: true
    })
  }
}
