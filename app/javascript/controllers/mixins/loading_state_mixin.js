// Mixin for managing loading states in Stimulus controllers (importmap version)
export const LoadingStateMixin = {
  initializeLoadingState() {
    this.isLoading = false
    this.loadingTimeouts = new Set()
    this.lastActionTime = null
    this.loadingConfig = { debounceDelay: 1000, timeoutDelay: 15000, maxTimeoutDelay: 30000 }
  },
  showLoading({ timeoutDelay = this.loadingConfig.timeoutDelay, onTimeout = () => this.resetLoading(), skipDuplicateCheck = false } = {}) {
    if (!skipDuplicateCheck && this.isDuplicateAction()) return false
    this.isLoading = true; this.lastActionTime = Date.now(); this.updateLoadingUI(true)
    if (timeoutDelay > 0) { const id = setTimeout(() => { onTimeout(); this.loadingTimeouts.delete(id) }, timeoutDelay); this.loadingTimeouts.add(id) }
    this.dispatchLoadingEvent('loading:start'); return true
  },
  hideLoading() { this.isLoading = false; this.clearLoadingTimeouts(); this.updateLoadingUI(false); this.dispatchLoadingEvent('loading:end') },
  resetLoading() { this.hideLoading() },
  isDuplicateAction() { if (!this.lastActionTime) return false; return (Date.now() - this.lastActionTime) < this.loadingConfig.debounceDelay },
  updateLoadingUI(isLoading) {
    if (this.hasLoadingTarget) this.loadingTarget.classList.toggle('hidden', !isLoading)
    if (this.hasSubmitTarget) this.submitTarget.disabled = isLoading
    if (this.hasFormTarget) this.formTarget.classList.toggle('loading', isLoading)
    if (typeof this.updateControllerUI === 'function') this.updateControllerUI(isLoading)
  },
  clearLoadingTimeouts() { this.loadingTimeouts.forEach((id) => clearTimeout(id)); this.loadingTimeouts.clear() },
  dispatchLoadingEvent(name, detail = {}) { const e = new CustomEvent(name, { detail: { controller: this, isLoading: this.isLoading, ...detail }, bubbles: true }); this.element.dispatchEvent(e) },
  configureLoading(config) { this.loadingConfig = { ...this.loadingConfig, ...config } },
  disconnectLoadingState() { this.clearLoadingTimeouts(); this.isLoading = false }
}

