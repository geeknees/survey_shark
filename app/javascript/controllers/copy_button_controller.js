import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['button', 'input']

  copy() {
    const text = this.inputTarget.value

    navigator.clipboard
      .writeText(text)
      .then(() => {
        // Success feedback
        const originalText = this.buttonTarget.textContent
        const originalClasses = this.buttonTarget.className

        this.buttonTarget.textContent = '✓ Copied!'
        this.buttonTarget.className =
          'bg-blue-600 hover:bg-blue-700 text-white px-3 py-2 rounded-lg text-sm transition-all duration-200 transform scale-95'

        // Reset after 2 seconds
        setTimeout(() => {
          this.buttonTarget.textContent = originalText
          this.buttonTarget.className = originalClasses
        }, 2000)
      })
      .catch((err) => {
        // Error feedback
        console.error('Failed to copy text: ', err)
        const originalText = this.buttonTarget.textContent
        const originalClasses = this.buttonTarget.className

        this.buttonTarget.textContent = '✗ Error'
        this.buttonTarget.className =
          'bg-red-600 hover:bg-red-700 text-white px-3 py-2 rounded-lg text-sm transition-all duration-200 transform scale-95'

        // Reset after 2 seconds
        setTimeout(() => {
          this.buttonTarget.textContent = originalText
          this.buttonTarget.className = originalClasses
        }, 2000)
      })
  }
}
