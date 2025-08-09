class OrchestrateInterviewJob < ApplicationJob
  queue_as :default

  # Orchestrates a single user turn using the non-streaming orchestrator.
  # @param conversation_id [Integer]
  # @param user_message_id [Integer]
  def perform(conversation_id, user_message_id)
    conversation = Conversation.find(conversation_id)
    user_message = Message.find(user_message_id)

    # Basic validation – rely on ActiveRecord::RecordNotFound for missing records
    return unless conversation.persisted? && user_message.persisted?

    orchestrator = Interview::Orchestrator.new(conversation)
    orchestrator.process_user_message(user_message)
  end
end
