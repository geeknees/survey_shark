// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import chatEventManager from "services/chat_event_manager"
import formValidator from "services/form_validator"

// Initialize auxiliary services on Turbo load
document.addEventListener('turbo:load', () => {
  try { chatEventManager.initialize() } catch (_) {}
  // Expose for optional use elsewhere
  try { window.ChatEventManager = chatEventManager; window.FormValidator = formValidator } catch (_) {}
})
