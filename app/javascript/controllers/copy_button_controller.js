import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['button', 'input']

  connect() {
    this._removeScaleTimeout = null
    this._resetTextTimeout = null
  }

  disconnect() {
    clearTimeout(this._removeScaleTimeout)
    clearTimeout(this._resetTextTimeout)
  }

  copy() {
    const text = this.inputTarget.value

    navigator.clipboard
      .writeText(text)
      .then(() => {
        const btn = this.buttonTarget
        const originalText = btn.textContent

        // Clear previous timeouts to avoid stacking
        clearTimeout(this._removeScaleTimeout)
        clearTimeout(this._resetTextTimeout)

        // Feedback text
        btn.textContent = '✓ Copied!'

        // Ensure transition classes exist on the button in the view
        // Then toggle a quick press animation using inline style to avoid Tailwind purge issues
        btn.style.transform = 'scale(0.95)'
        this._removeScaleTimeout = setTimeout(() => {
          btn.style.transform = ''
        }, 180)

        // Reset text after a moment
        this._resetTextTimeout = setTimeout(() => {
          btn.textContent = originalText
        }, 1500)
      })
      .catch((err) => {
        console.error('Failed to copy text: ', err)
        const btn = this.buttonTarget
        const originalText = btn.textContent

        clearTimeout(this._removeScaleTimeout)
        clearTimeout(this._resetTextTimeout)

        btn.textContent = '✗ Error'
        btn.style.transform = 'scale(0.95)'
        this._removeScaleTimeout = setTimeout(() => {
          btn.style.transform = ''
        }, 180)

        this._resetTextTimeout = setTimeout(() => {
          btn.textContent = originalText
        }, 1500)
      })
  }
}
