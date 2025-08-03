module Interview
  class BroadcastManager
    def initialize(conversation)
      @conversation = conversation
      @last_broadcast_time = Time.current
      @debounce_interval = 0.1 # 100ms debounce
    end

    def broadcast_streaming_update(message, chunk)
      # Only broadcast if enough time has passed to prevent excessive updates
      return if Time.current - @last_broadcast_time < @debounce_interval

      begin
        # Update the entire message instead of streaming to a non-existent target
        Turbo::StreamsChannel.broadcast_replace_to(
          @conversation,
          target: "message_#{message.id}",
          partial: "conversations/message",
          locals: { message: message }
        )
        @last_broadcast_time = Time.current
      rescue => e
        Rails.logger.error "Failed to broadcast streaming update: #{e.message}"
        # Continue execution even if broadcast fails
      end
    end

    def broadcast_final_update(reset_form: true)
      begin
        # Broadcast complete message list update
        Turbo::StreamsChannel.broadcast_replace_to(
          @conversation,
          target: "messages",
          partial: "conversations/messages",
          locals: { messages: @conversation.messages.order(:created_at) }
        )

        # Reset form if requested
        if reset_form
          broadcast_form_reset
        end
      rescue => e
        Rails.logger.error "Failed to broadcast final update: #{e.message}"
        # Attempt fallback broadcast
        broadcast_fallback_update
      end
    end

    def broadcast_message_update(message, reset_form: true)
      # Use the same logic as broadcast_final_update for consistency
      broadcast_final_update(reset_form: reset_form)
    end

    private

    def broadcast_form_reset
      # Use a more reliable approach: broadcast a custom Turbo Stream action
      Rails.logger.info "Broadcasting form reset event"

      # Use a span element that triggers a custom event when added to DOM
      Turbo::StreamsChannel.broadcast_action_to(
        @conversation,
        action: "append",
        target: "messages",
        html: "<span id='form-reset-#{Time.current.to_i}' data-form-reset='true' style='display: none;'></span>".html_safe
      )
    end

    def broadcast_fallback_update
      # Fallback: force page reload if broadcast fails
      Turbo::StreamsChannel.broadcast_action_to(
        @conversation,
        action: "append",
        target: "messages",
        html: "<script>
          console.warn('Broadcast failed, reloading page...');
          setTimeout(() => window.location.reload(), 1000);
        </script>".html_safe
      )
    rescue => e
      Rails.logger.error "Fallback broadcast also failed: #{e.message}"
      # At this point, we can't do much more
    end
  end
end
