import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  connect() {
    console.log('form-reset controller connected')
  }

  triggerReset() {
    console.log('triggerReset called, dispatching chat:response-complete event')
    document.dispatchEvent(new CustomEvent('chat:response-complete'))

    // Remove this element after triggering the event
    this.element.remove()
  }
}
