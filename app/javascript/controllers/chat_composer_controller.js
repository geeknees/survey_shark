import { Controller } from '@hotwired/stimulus'

// Debug helpers (enable by setting window.SURVEY_SHARK_DEBUG = true)
const dlog = (...args) => {
  try {
    if (window && window.SURVEY_SHARK_DEBUG) console.log(...args)
  } catch (_) {}
}
const dwarn = (...args) => {
  try {
    if (window && window.SURVEY_SHARK_DEBUG) console.warn(...args)
  } catch (_) {}
}

export default class extends Controller {
  static targets = ['form', 'textarea', 'submit', 'counter', 'loading']

  connect() {
    dlog('chat-composer controller connected')
    this.updateCounter()
    this.updateSubmitButton()
    this.isSubmitting = false

    // Set up observer to watch for form reset signals
    this.setupFormResetObserver()
  }

  disconnect() {
    if (this.formResetObserver) {
      this.formResetObserver.disconnect()
    }
  }

  textareaTargetConnected() {
    this.isComposing = false

    this.textareaTarget.addEventListener('compositionstart', () => {
      this.isComposing = true
    })

    this.textareaTarget.addEventListener('compositionend', () => {
      this.isComposing = false
      this.updateCounter()
      this.updateSubmitButton()
    })

    this.textareaTarget.addEventListener('input', () => {
      this.updateCounter()
      this.updateSubmitButton()
    })

    this.textareaTarget.addEventListener('keydown', (event) => {
      if (event.isComposing || this.isComposing) return
      if (event.key === 'Enter' && !event.shiftKey) {
        event.preventDefault()
        if (this.canSubmit() && !this.isSubmitting) {
          dlog('Enter key pressed, submitting form via requestSubmit')
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
      dwarn('Preventing duplicate submission')
      return
    }
    this.lastSubmitTime = now

    // Defer state changes to handleSubmit; just trigger native submit
    this.formTarget.requestSubmit()
  }

  async handleSubmit(event) {
    // Always prevent navigation; we post via fetch and rely on Turbo Streams updates
    event.preventDefault()

    if (this.isSubmitting || !this.canSubmit()) {
      dwarn('Skipping submit: already submitting or cannot submit')
      return
    }

    dlog('Form submitted, showing loading state')
    this.showLoading()
    this.isSubmitting = true

    // Fallback: Reset form after 20 seconds if no other reset occurs
    this.fallbackResetTimeout = setTimeout(() => {
      if (this.isSubmitting) {
        dwarn('Fallback timeout reached (20s), resetting form')
        this.resetForm()
      }
    }, 20000)

    try {
      const form = this.formTarget
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
      if (res && res.ok) {
        // Clear input content immediately after successful POST
        this.clearTextarea()
        // Kick a lightweight messages refresh loop as a safety net
        this.pollForAssistantResponse()
      } else {
        dwarn('Form post returned non-OK status:', res?.status)
        this.resetForm()
      }
      // No navigation. Streaming job will update UI and trigger reset via broadcast.
    } catch (e) {
      console.error('Form post failed', e)
      this.resetForm()
    }
  }

  messagesUrl() {
    try {
      const url = new URL(window.location.href)
      const path = url.pathname.replace(
        /\/conversations\/(\d+)(?:\/.*)?$/,
        '/conversations/$1/messages'
      )
      return path + url.search
    } catch (_) {
      return null
    }
  }

  async pollForAssistantResponse() {
    const url = this.messagesUrl()
    if (!url) {
      dwarn('Cannot poll for response: no messages URL')
      return
    }

    const start = Date.now()
    const timeoutMs = 15000 // 15s safety window
    const intervalMs = 1000

    const getLastDomId = () => {
      const container = document.getElementById('messages')
      if (!container) return null
      const nodes = Array.from(container.querySelectorAll('[id^="message_"]'))
      if (nodes.length === 0) return null
      const last = nodes[nodes.length - 1]
      const m = last.id.match(/message_(\d+)/)
      return m ? parseInt(m[1], 10) : null
    }

    const initialLastId = getLastDomId()

    while (Date.now() - start < timeoutMs && this.isSubmitting) {
      try {
        const res = await fetch(url, {
          headers: { 'X-Requested-With': 'XMLHttpRequest' }
        })
        if (!res.ok) {
          dwarn('Poll fetch failed with status:', res.status)
          break
        }
        const html = await res.text()
        const doc = new DOMParser().parseFromString(html, 'text/html')
        const newMessages = doc.querySelector('#messages')
        const current = document.getElementById('messages')

        const newProgress = doc.querySelector('#conversation_progress')
        const currentProgress = document.getElementById('conversation_progress')
        if (newProgress && currentProgress) {
          currentProgress.innerHTML = newProgress.innerHTML
        }

        if (newMessages && current) {
          current.innerHTML = newMessages.innerHTML
          const lastId = getLastDomId()
          if (!initialLastId || (lastId && lastId > initialLastId)) {
            // New message appended; reset loading state explicitly in fallback path
            dlog('New message detected, resetting form from poll')
            this.resetForm()
            break
          }
        }
      } catch (e) {
        dwarn('Poll iteration failed:', e)
        // ignore and continue
      }
      await new Promise((r) => setTimeout(r, intervalMs))
    }

    // If we exit the loop while still submitting, timeout occurred
    if (this.isSubmitting) {
      dwarn('Poll timeout reached without new message')
    }
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
    dlog(
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
    dlog('resetForm called, hiding loading and clearing textarea')
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

  // Optimistically clear only the textarea (keep loading state)
  clearTextarea() {
    if (this.hasTextareaTarget) {
      this.textareaTarget.value = ''
      this.updateCounter()
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

  setupFormResetObserver() {
    // Watch for form reset signals in the messages container
    const messagesContainer = document.getElementById('messages')
    if (!messagesContainer) {
      dwarn('Messages container not found, cannot set up form reset observer')
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
              dlog('Form reset signal detected, resetting form')
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

    dlog('Form reset observer set up successfully')
  }
}
