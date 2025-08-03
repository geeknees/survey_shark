require_relative "../services/llm/client/openai"
require_relative "../services/interview/fallback_orchestrator"

class StreamAssistantResponseJob < ApplicationJob
  queue_as :default

  def perform(conversation_id, user_message_id)
    conversation = Conversation.find(conversation_id)
    user_message = Message.find(user_message_id)

    # Check if already in fallback mode or should use fallback
    if conversation.state == "fallback" || fallback_mode?(conversation)
      # Use fallback orchestrator for fallback mode
      fallback_orchestrator = Interview::FallbackOrchestrator.new(conversation)
      fallback_orchestrator.process_user_message(user_message)
      return
    end

    begin
      # Use streaming orchestrator for OpenAI
      llm_client = Rails.env.test? ? nil : LLM::Client::OpenAI.new
      streaming_orchestrator = Interview::StreamingOrchestrator.new(conversation, llm_client: llm_client)
      streaming_orchestrator.process_user_message_with_streaming(user_message)
    rescue LLM::Client::OpenAI::OpenAIError, StandardError => e
      Rails.logger.error "LLM error in streaming job, falling back: #{e.message}"

      # Update conversation state to fallback mode
      conversation.update!(
        state: "fallback",
        meta: (conversation.meta || {}).merge(fallback_mode: true)
      )

      # Fall back to fallback orchestrator
      fallback_orchestrator = Interview::FallbackOrchestrator.new(conversation)
      fallback_orchestrator.process_user_message(user_message)
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
