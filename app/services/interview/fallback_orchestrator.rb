module Interview
  class FallbackOrchestrator
    FALLBACK_QUESTIONS = [
      "最近直面した課題や不便と、その具体的な場面を教えてください。",
      "先ほど挙げられた中から、最も重要だと思う1件を選び、その理由を一言で教えてください。",
      "今思っていることを書いてください。"
  ].freeze

  def initialize(conversation)
    @conversation = conversation
  end

  def process_user_message(user_message)
    # Mark conversation as using fallback mode
    @conversation.update!(
      state: "fallback",
      meta: (@conversation.meta || {}).merge(fallback_mode: true)
    )

    question_number = determine_question_number

    if question_number <= FALLBACK_QUESTIONS.length
      assistant_content = FALLBACK_QUESTIONS[question_number - 1]

      # Create assistant message
      @conversation.messages.create!(
        role: 1, # assistant
        content: assistant_content
      )
    else
      # All questions asked, finish conversation
      assistant_content = "ご協力いただき、ありがとうございました。貴重なお話をお聞かせいただけました。"

      @conversation.messages.create!(
        role: 1, # assistant
        content: assistant_content
      )

      @conversation.update!(
        state: "done",
        finished_at: Time.current
      )

      # Enqueue analysis job for finished conversation
      AnalyzeConversationJob.perform_later(@conversation.id)
    end

    assistant_content
  end

  private

  def determine_question_number
    # Count user messages (excluding skip messages) to determine which question to ask
    user_messages_count = @conversation.messages
                                     .where(role: 0)
                                     .where.not(content: "[スキップ]")
                                     .count

    # Return the next question number (1-indexed)
    user_messages_count
  end
  end
end
