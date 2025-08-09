require_relative "../services/llm/client/openai"
require_relative "../services/interview/fallback_orchestrator"

class StreamAssistantResponseJob < ApplicationJob
  queue_as :default

  # Prevent multiple jobs for the same conversation from running simultaneously
  def perform(conversation_id, user_message_id)
    conversation = Conversation.find(conversation_id)
    user_message = Message.find(user_message_id)

    # Use a simple in-memory lock to prevent race conditions
    # In production, consider using Redis for distributed locking
    lock_key = "conversation_#{conversation_id}_processing"

    if Rails.cache.exist?(lock_key)
      Rails.logger.warn "Conversation #{conversation_id} is already being processed, skipping job"
      return
    end

    begin
      # Set lock with expiration (safety net in case job crashes)
      Rails.cache.write(lock_key, true, expires_in: 5.minutes)

      # Validate conversation state before processing
      unless conversation.persisted? && user_message.persisted?
        Rails.logger.error "Invalid conversation or message state: conversation=#{conversation.id}, message=#{user_message.id}"
        return
      end

      process_conversation(conversation, user_message)
    ensure
      # Always release the lock
      Rails.cache.delete(lock_key)
    end
  end

  private

  def process_conversation(conversation, user_message)
    # Check if already in fallback mode or should use fallback
    if conversation.state == "fallback" || fallback_mode?(conversation)
      # Use fallback orchestrator for fallback mode
      fallback_orchestrator = Interview::FallbackOrchestrator.new(conversation)
      fallback_orchestrator.process_user_message(user_message)
      return
    end

    begin
      # Use streaming orchestrator for OpenAI
      llm_client = if Rails.env.test?
        # Allow tests to trigger real client (and thus stubbed HTTP + fallback behavior)
        ENV["OPENAI_API_KEY"].present? ? LLM::Client::OpenAI.new : nil
      else
        LLM::Client::OpenAI.new
      end
      streaming_orchestrator = Interview::StreamingOrchestrator.new(conversation, llm_client: llm_client)
      streaming_orchestrator.process_user_message_with_streaming(user_message)
    rescue LLM::Client::OpenAI::OpenAIError, StandardError => e
      Rails.logger.error "LLM error in streaming job, falling back: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace&.first(10)&.join("\n")}"

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

  def fallback_mode?(conversation)
    conversation.meta&.dig("fallback_mode") == true
  end
end
