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

// Fallback: if Turbo Stream broadcasts are missed (e.g., page redirects
// before subscription), perform a few lightweight refreshes of the messages
// partial to reconcile the UI.
export default class extends Controller {
  static values = {
    attempts: { type: Number, default: 4 },
    interval: { type: Number, default: 1500 } // ms
  }

  connect() {
    // Small initial delay to allow Turbo stream subscription to settle
    this._attempt = 0
    this._timer = setTimeout(() => this.refreshLoop(), 700)
    dlog(
      'messages-refresher connected, will attempt',
      this.attemptsValue,
      'refreshes'
    )
  }

  disconnect() {
    if (this._timer) clearTimeout(this._timer)
  }

  async refreshLoop() {
    try {
      await this.refreshOnce()
    } catch (e) {
      dwarn('messages-refresher: refresh failed', e)
    }

    this._attempt += 1
    if (this._attempt < this.attemptsValue) {
      this._timer = setTimeout(() => this.refreshLoop(), this.intervalValue)
    } else {
      dlog('messages-refresher: completed', this._attempt, 'attempts')
    }
  }

  async refreshOnce() {
    const url = this.messagesUrl()
    if (!url) {
      dwarn('messages-refresher: no URL available')
      return
    }

    const res = await fetch(url, {
      headers: { 'X-Requested-With': 'XMLHttpRequest' }
    })
    if (!res.ok) {
      dwarn('messages-refresher: fetch returned status', res.status)
      return
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
      // Replace inner content to avoid losing the container reference
      current.innerHTML = newMessages.innerHTML

      // Auto-scroll to bottom to keep latest messages in view
      try {
        current.scrollTop = current.scrollHeight
      } catch (e) {
        dwarn('messages-refresher: scroll failed', e)
      }
    }
  }

  messagesUrl() {
    try {
      const url = new URL(window.location.href)
      // /conversations/:id/messages
      const path = url.pathname.replace(
        /\/conversations\/(\d+)(?:\/.*)?$/,
        '/conversations/$1/messages'
      )
      return path + url.search
    } catch (e) {
      dwarn('messages-refresher: URL parsing failed', e)
      return null
    }
  }
}
