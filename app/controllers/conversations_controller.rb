class ConversationsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_conversation

  def show
    @messages = @conversation.messages.order(:created_at)
    @user_turn_count = @conversation.messages.where(role: 0).count
    @max_turns = @conversation.project.limits.dig("max_turns") || 12
    @remaining_turns = [ @max_turns - @user_turn_count, 0 ].max
  end

  def create_message
    content = params[:content]&.strip
    return redirect_to @conversation if content.blank?

    # Create user message
    user_message = @conversation.messages.create!(
      role: 0, # user
      content: content.truncate(500)
    )

    # Enqueue PII detection for user message
    PiiDetectJob.perform_later(user_message.id)

    # Enqueue streaming orchestration job
    StreamAssistantResponseJob.perform_later(@conversation.id, user_message.id)

    redirect_to @conversation
  end

  def skip
    # Create skip message
    user_message = @conversation.messages.create!(
      role: 0, # user
      content: "[スキップ]"
    )

    # Skip PII detection for skip messages (no personal info in "[スキップ]")

    # Enqueue streaming orchestration job
    StreamAssistantResponseJob.perform_later(@conversation.id, user_message.id)

    redirect_to @conversation
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:id])
  end
end
