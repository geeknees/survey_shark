// Centralized event management for chat functionality (importmap version)
class ChatEventManager {
  constructor() {
    this.eventHandlers = new Map()
    this.debounceTimers = new Map()
    this.initialized = false
  }

  initialize() {
    if (this.initialized) return
    this.setupGlobalEventListeners()
    this.initialized = true
  }

  setupGlobalEventListeners() {
    document.addEventListener('turbo:before-stream-render', (event) => {
      this.handleTurboStreamRender(event)
    })

    document.addEventListener('submit', (event) => {
      if (event.target.matches('[data-controller*="chat-composer"]')) {
        this.handleChatFormSubmit(event)
      }
    })
  }

  handleTurboStreamRender(event) {
    const { target } = event.detail
    if (target && target.matches('#messages')) {
      this.debounceEmit('messages:updated', { container: target })
    }
  }

  handleChatFormSubmit(event) {
    this.emit('chat:form:submit', { form: event.target })
  }

  emit(eventName, detail = {}) {
    const event = new CustomEvent(eventName, { detail, bubbles: true })
    document.dispatchEvent(event)
  }

  debounceEmit(eventName, detail = {}, delay = 300) {
    const timerId = this.debounceTimers.get(eventName)
    if (timerId) clearTimeout(timerId)
    const newTimerId = setTimeout(() => {
      this.emit(eventName, detail)
      this.debounceTimers.delete(eventName)
    }, delay)
    this.debounceTimers.set(eventName, newTimerId)
  }

  on(eventName, handler, options = {}) {
    if (!this.eventHandlers.has(eventName)) {
      this.eventHandlers.set(eventName, new Set())
    }
    const wrapped = (event) => {
      try { handler(event) } catch (e) { /* swallow */ }
    }
    this.eventHandlers.get(eventName).add(wrapped)
    document.addEventListener(eventName, wrapped, options)
    return () => this.off(eventName, wrapped)
  }

  off(eventName, handler) {
    const handlers = this.eventHandlers.get(eventName)
    if (!handlers) return
    handlers.delete(handler)
    document.removeEventListener(eventName, handler)
    if (handlers.size === 0) this.eventHandlers.delete(eventName)
  }

  destroy() {
    this.debounceTimers.forEach((id) => clearTimeout(id))
    this.debounceTimers.clear()
    this.eventHandlers.forEach((set, name) => set.forEach((h) => document.removeEventListener(name, h)))
    this.eventHandlers.clear()
    this.initialized = false
  }
}

const chatEventManager = new ChatEventManager()
export default chatEventManager

