# ABOUTME: Generates assistant responses based on state and conversation context.
# ABOUTME: Adds must-ask sequencing with deterministic follow-up prompts.
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
    def generate_response(state, user_message, deepening_turn_count = 0)
      # For structured states, use predefined questions directly without LLM
      # This ensures consistent, appropriate questions at each stage
      case state
      when "intro", "enumerate", "choose", "deepening", "must_ask"
        generate_structured_response(state, deepening_turn_count)
      when "summary_check"
        # Use LLM to generate a natural summary
        summary = generate_conversation_summary
        behavior_prompt = @prompt_builder.behavior_prompt_for_state(state, deepening_turn_count)
        behavior_prompt.gsub("{summary}", summary).split("\n\n").last
      when "recommend"
        # Use LLM to identify and recommend the most important pain point
        messages = build_conversation_history
        system_prompt = @prompt_builder.system_prompt
        most_important = identify_most_important_pain_point
        behavior_prompt = @prompt_builder.behavior_prompt_for_state(state, deepening_turn_count)
        behavior_prompt = behavior_prompt.gsub("{most_important}", most_important)

        @llm_client.generate_response(
          system_prompt: system_prompt,
          behavior_prompt: behavior_prompt,
          conversation_history: messages,
          user_message: user_message.content
        )
      else
        # For other states, use LLM
        messages = build_conversation_history
        system_prompt = @prompt_builder.system_prompt
        behavior_prompt = @prompt_builder.behavior_prompt_for_state(state, deepening_turn_count)

        @llm_client.generate_response(
          system_prompt: system_prompt,
          behavior_prompt: behavior_prompt,
          conversation_history: messages,
          user_message: user_message.content
        )
      end
    end

    private

    def generate_structured_response(state, deepening_turn_count)
      return must_ask_question if state == "must_ask"

      # Return the predefined question directly
      behavior_prompt = @prompt_builder.behavior_prompt_for_state(state, deepening_turn_count)
      # Extract just the question part (after the directive)
      behavior_prompt.split("\n\n").last
    end

    def must_ask_question
      must_ask_manager = Interview::MustAskManager.new(@project, @conversation.meta)
      must_ask_manager.question
    end

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
                                          .where.not(content: "[インタビュー開始]")
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
      # Exclude system messages, skip messages, and completion indicators
      completion_patterns = [ "以上", "それだけ", "終わり", "ない", "特にない" ]
      user_messages.reject { |msg|
        msg == "[スキップ]" ||
        msg == "[インタビュー開始]" ||
        msg.strip.empty? ||
        completion_patterns.any? { |pattern| msg.include?(pattern) && msg.length < 10 }
      }
    end
  end
end
