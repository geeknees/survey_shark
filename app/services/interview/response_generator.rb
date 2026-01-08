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
      behavior_prompt = @prompt_builder.behavior_prompt_for_state_with_context(
        state,
        deepening_turn: deepening_turn_count,
        conversation: @conversation
      )

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
  end
end
