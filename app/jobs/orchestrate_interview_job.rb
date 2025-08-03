class OrchestrateInterviewJob < ApplicationJob
  queue_as :default

  def perform(conversation_id, user_message_id)
    conversation = Conversation.find(conversation_id)
    user_message = Message.find(user_message_id)

    orchestrator = Interview::Orchestrator.new(conversation)
    orchestrator.process_user_message(user_message)

    # Broadcast the updated conversation via Turbo Stream
    broadcast_conversation_update(conversation)
  end

  private

  def broadcast_conversation_update(conversation)
    # This will trigger a Turbo Stream update to refresh the conversation view
    Turbo::StreamsChannel.broadcast_replace_to(
      conversation,
      target: "messages",
      partial: "conversations/messages",
      locals: { messages: conversation.messages.order(:created_at) }
    )
  end
end
