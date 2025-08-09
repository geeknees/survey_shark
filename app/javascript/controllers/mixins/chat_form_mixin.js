// Mixin for chat form functionality (importmap version)
export const ChatFormMixin = {
  initializeChatForm() {
    this.setupEventListeners(); this.setupFormResetObserver(); this.updateFormState()
  },
  setupEventListeners() {
    this.responseCompleteHandler = () => { this.resetChatForm() }
    document.addEventListener('chat:response-complete', this.responseCompleteHandler)
    if (this.hasTextareaTarget) {
      this.textareaTarget.addEventListener('input', () => this.updateFormState())
      this.textareaTarget.addEventListener('keydown', (event) => this.handleKeyDown(event))
    }
  },
  handleKeyDown(event) { if (event.key === 'Enter' && !event.shiftKey) { event.preventDefault(); if (this.canSubmitForm() && !this.isLoading) this.submitChatForm() } },
  submitChatForm() { if (!this.canSubmitForm() || this.isLoading) return false; if (!this.showLoading()) return false; if (this.hasFormTarget) this.formTarget.requestSubmit(); return true },
  handleChatFormSubmit(event) { if (!this.canSubmitForm() || this.isLoading) { event.preventDefault(); return } this.showLoading({ timeoutDelay: 15000, onTimeout: () => this.resetChatForm() }) },
  resetChatForm() { if (this.hasTextareaTarget) this.textareaTarget.value = ''; this.updateFormState(); this.hideLoading() },
  canSubmitForm() { if (!this.hasTextareaTarget) return false; const text = this.textareaTarget.value.trim(); return text.length > 0 && text.length <= 500 },
  updateFormState() { this.updateCharacterCounter(); this.updateSubmitButton() },
  updateCharacterCounter() { if (this.hasCounterTarget && this.hasTextareaTarget) { const len = this.textareaTarget.value.length; this.counterTarget.textContent = len; if (len > 450) this.counterTarget.classList.add('text-red-500'); else if (len > 400) this.counterTarget.classList.add('text-yellow-500'); else this.counterTarget.classList.remove('text-red-500', 'text-yellow-500') } },
  updateSubmitButton() { if (this.hasSubmitTarget) { const ok = this.canSubmitForm() && !this.isLoading; this.submitTarget.disabled = !ok; if (ok) this.submitTarget.classList.remove('opacity-50', 'cursor-not-allowed'); else this.submitTarget.classList.add('opacity-50', 'cursor-not-allowed') } },
  insertQuickReply(event) { const text = event.currentTarget.dataset.text; if (this.hasTextareaTarget) { this.textareaTarget.value = text; this.updateFormState(); this.textareaTarget.focus() } },
  setupFormResetObserver() { if (!this.hasFormTarget) return; this.formResetObserver = new MutationObserver((mutations) => { mutations.forEach((m) => { if (m.type === 'attributes' && m.attributeName === 'data-reset' && this.formTarget.dataset.reset === 'true') { this.resetChatForm(); delete this.formTarget.dataset.reset } }) }); this.formResetObserver.observe(this.formTarget, { attributes: true, attributeFilter: ['data-reset'] }) },
  updateControllerUI(_isLoading) {},
  disconnectChatForm() { if (this.responseCompleteHandler) document.removeEventListener('chat:response-complete', this.responseCompleteHandler); if (this.formResetObserver) this.formResetObserver.disconnect() }
}

