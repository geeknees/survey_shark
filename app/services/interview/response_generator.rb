module Interview
  # Generates AI assistant responses based on conversation state and context
  class ResponseGenerator
    def initialize(conversation, project, llm_client, prompt_builder)
      @conversation = conversation
      @project = project
      @llm_client = llm_client
      @prompt_builder = prompt_builder
    end

    # Generate assistant response for the given state
    def generate_response(state, user_message)
      messages = build_conversation_history
      system_prompt = @prompt_builder.system_prompt
      behavior_prompt = @prompt_builder.behavior_prompt_for_state(state)

      # For summary_check state, include actual summary
      if state == "summary_check"
        summary = generate_conversation_summary
        behavior_prompt = behavior_prompt.gsub("{summary}", summary)
      end

      # For recommend state, identify most important pain point
      if state == "recommend"
        most_important = identify_most_important_pain_point
        behavior_prompt = behavior_prompt.gsub("{most_important}", most_important)
      end

      @llm_client.generate_response(
        system_prompt: system_prompt,
        behavior_prompt: behavior_prompt,
        conversation_history: messages,
        user_message: user_message.content
      )
    end

    private

    def build_conversation_history
      @conversation.messages.order(:created_at).map do |message|
        {
          role: message.user? ? "user" : "assistant",
          content: message.content
        }
      end
    end

    def identify_most_important_pain_point
      # Simple heuristic - in real implementation this would use LLM analysis
      pain_points = extract_pain_points_from_conversation
      pain_points.first || "お話しいただいた課題"
    end

    def generate_conversation_summary
      user_messages = @conversation.messages.where(role: 0)
                                          .where.not(content: "[スキップ]")
                                          .pluck(:content)

      if user_messages.any?
        "主な課題: #{user_messages.join('、')}"
      else
        "お話しいただいた内容"
      end
    end

    def extract_pain_points_from_conversation
      # Simple extraction - in real implementation this would be more sophisticated
      user_messages = @conversation.messages.where(role: 0).pluck(:content)
      # Exclude system messages and skip messages
      user_messages.reject { |msg| msg == "[スキップ]" || msg == "[インタビュー開始]" }
    end
  end
end
