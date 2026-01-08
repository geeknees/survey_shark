# ABOUTME: Generates assistant responses based on state and conversation context.
# ABOUTME: Guides LLM responses for must-ask sequencing and follow-ups.
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
      messages = build_conversation_history
      system_prompt = @prompt_builder.system_prompt
      behavior_prompt = build_behavior_prompt(state, deepening_turn_count)

      @llm_client.generate_response(
        system_prompt: system_prompt,
        behavior_prompt: behavior_prompt,
        conversation_history: messages,
        user_message: user_message.content
      )
    end

    private

    def build_behavior_prompt(state, deepening_turn_count)
      case state
      when "summary_check"
        summary = generate_conversation_summary
        @prompt_builder.behavior_prompt_for_state(state, deepening_turn_count)
                      .gsub("{summary}", summary)
      when "must_ask"
        must_ask_manager = Interview::MustAskManager.new(@project, @conversation.meta)
        @prompt_builder.behavior_prompt_for_state(
          state,
          deepening_turn_count,
          must_ask_item: must_ask_manager.current_item,
          must_ask_followup: must_ask_manager.followup?
        )
      else
        @prompt_builder.behavior_prompt_for_state(state, deepening_turn_count)
      end
    end
    def build_conversation_history
      @conversation.messages.order(:created_at).map do |message|
        {
          role: message.user? ? "user" : "assistant",
          content: message.content
        }
      end
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

  end
end
