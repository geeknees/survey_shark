require_relative "../services/llm/client/openai"

class StreamAssistantResponseJob < ApplicationJob
  queue_as :default

  def perform(conversation_id, user_message_id)
    conversation = Conversation.find(conversation_id)
    user_message = Message.find(user_message_id)

    # Check if already in fallback mode or should use fallback
    if conversation.state == "fallback" || fallback_mode?(conversation)
      # Use regular orchestrator for fallback (no streaming needed)
      orchestrator = Interview::Orchestrator.new(conversation)
      response = orchestrator.process_user_message(user_message)
      broadcast_complete_response(conversation, response)
      return
    end

    begin
      # Use streaming orchestrator for OpenAI
      streaming_orchestrator = Interview::StreamingOrchestrator.new(conversation)
      streaming_orchestrator.process_user_message_with_streaming(user_message)
    rescue LLM::Client::OpenAI::OpenAIError => e
      Rails.logger.error "LLM error in streaming job, falling back: #{e.message}"

      # Fall back to fallback orchestrator
      fallback_orchestrator = Interview::FallbackOrchestrator.new(conversation)
      response = fallback_orchestrator.process_user_message(user_message)
      broadcast_complete_response(conversation, response)
    end
  end

  private

  def fallback_mode?(conversation)
    conversation.meta&.dig("fallback_mode") == true
  end

  def broadcast_complete_response(conversation, response)
    # Broadcast the complete response
    Turbo::StreamsChannel.broadcast_replace_to(
      conversation,
      target: "messages",
      partial: "conversations/messages",
      locals: { messages: conversation.messages.order(:created_at) }
    )

    # Broadcast custom script to reset form
    Turbo::StreamsChannel.broadcast_action_to(
      conversation,
      action: "append",
      target: "messages",
      html: "<script>
        document.dispatchEvent(new CustomEvent('chat:response-complete'));
      </script>".html_safe
    )
  end
end
