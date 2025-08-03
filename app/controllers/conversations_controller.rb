class ConversationsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_conversation

  def show
    @messages = @conversation.messages.order(:created_at)
    @user_turn_count = @conversation.messages.where(role: 0).count
    @max_turns = @conversation.project.limits.dig("max_turns") || 12
    @remaining_turns = [@max_turns - @user_turn_count, 0].max
  end

  def create_message
    content = params[:content]&.strip
    return redirect_to @conversation if content.blank?

    # Create user message
    @conversation.messages.create!(
      role: 0, # user
      content: content.truncate(500)
    )

    # TODO: Enqueue orchestration job in next prompt
    
    redirect_to @conversation
  end

  def skip
    # Create skip message
    @conversation.messages.create!(
      role: 0, # user
      content: "[スキップ]"
    )

    # TODO: Enqueue orchestration job in next prompt
    
    redirect_to @conversation
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:id])
  end
end