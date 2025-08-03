class PiiDetectJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find(message_id)
    
    # Only process user messages
    return unless message.user?
    
    # Skip if already processed
    return if message.meta&.dig("pii_processed")
    
    detector = PII::Detector.new
    result = detector.analyze(message.content)
    
    if result.pii_detected?
      # Create masked version
      masked_content = result.masked_content
      
      # Update message with masked content and mark as processed
      message.update!(
        content: masked_content,
        meta: (message.meta || {}).merge(
          pii_processed: true,
          pii_detected: true,
          original_content_hash: Digest::SHA256.hexdigest(message.content)
        )
      )
      
      # Broadcast updates
      broadcast_message_update(message)
      broadcast_pii_warning(message.conversation)
      
      Rails.logger.info "PII detected and masked in message #{message.id}"
    else
      # Mark as processed but no PII found
      message.update!(
        meta: (message.meta || {}).merge(
          pii_processed: true,
          pii_detected: false
        )
      )
    end
  end

  private

  def broadcast_message_update(message)
    # Replace the specific message in the DOM
    Turbo::StreamsChannel.broadcast_replace_to(
      message.conversation,
      target: "message_#{message.id}",
      partial: "conversations/message",
      locals: { message: message }
    )
  end

  def broadcast_pii_warning(conversation)
    # Add warning banner near the composer
    Turbo::StreamsChannel.broadcast_append_to(
      conversation,
      target: "pii-warnings",
      partial: "conversations/pii_warning"
    )
  end
end