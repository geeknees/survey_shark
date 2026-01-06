class ConversationsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_conversation

  def show
    @messages = @conversation.messages.order(:created_at)
    @user_turn_count = @conversation.messages.where(role: 0).count.to_i
    @max_turns = (@conversation.project.limits.dig("max_turns") || 12).to_i
    @remaining_turns = [ @max_turns - @user_turn_count, 0 ].max
    @debug_mode = debug_mode?

    if @debug_mode && @conversation.meta&.dig("debug_mode") != true
      @conversation.update!(meta: @conversation.meta.merge("debug_mode" => true))
    end
  end

  def create_message
    content = params[:content]&.strip
    return redirect_to @conversation if content.blank?

    if debug_mode? && @conversation.meta&.dig("debug_mode") != true
      @conversation.update!(meta: @conversation.meta.merge("debug_mode" => true))
    end

    # Check if conversation is already finished
    return redirect_to @conversation if @conversation.finished_at.present?

    # Check turn limit before creating message
    user_turn_count = @conversation.messages.where(role: 0).count.to_i
    max_turns = (@conversation.project.limits.dig("max_turns") || 12).to_i

    if user_turn_count >= max_turns
      # Mark conversation as finished if turn limit reached
      @conversation.update!(finished_at: Time.current) unless @conversation.finished_at.present?
      return redirect_to @conversation
    end

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
    # Check if conversation is already finished
    return redirect_to @conversation if @conversation.finished_at.present?

    if debug_mode? && @conversation.meta&.dig("debug_mode") != true
      @conversation.update!(meta: @conversation.meta.merge("debug_mode" => true))
    end

    # Check turn limit before creating skip message
    user_turn_count = @conversation.messages.where(role: 0).count.to_i
    max_turns = (@conversation.project.limits.dig("max_turns") || 12).to_i

    if user_turn_count >= max_turns
      # Mark conversation as finished if turn limit reached
      @conversation.update!(finished_at: Time.current) unless @conversation.finished_at.present?
      return redirect_to @conversation
    end

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

  # Lightweight messages partial for polling fallback
  def messages
    @messages = @conversation.messages.order(:created_at)
    @debug_mode = debug_mode?
    render partial: "conversations/poll", locals: { conversation: @conversation, messages: @messages }
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:id])
  end

  def debug_mode?
    return true if ENV["INTERVIEW_DEBUG"].to_s == "true"
    return false unless Rails.env.development? || Rails.env.test?

    params[:debug].present?
  end
end
