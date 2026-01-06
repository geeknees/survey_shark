module Interview
  class Orchestrator
    STATES = %w[intro enumerate recommend choose deepening summary_check done].freeze

    def initialize(conversation, llm_client: nil)
      @conversation = conversation
      @project = @conversation.project
      @llm_client = llm_client || default_llm_client
      @prompt_builder = Interview::PromptBuilder.new(@project)
      @state_machine = Interview::StateMachine.new(@conversation, @project)
      @response_generator = Interview::ResponseGenerator.new(
        @conversation,
        @project,
        @llm_client,
        @prompt_builder
      )
    end

    def process_user_message(user_message)
      # Check if already in fallback mode
      if @conversation.state == "fallback" || fallback_mode?
        return Interview::FallbackOrchestrator.new(@conversation).process_user_message(user_message)
      end

      begin
        # Check turn limit before processing
        if @state_machine.turn_limit_reached?
          return handle_turn_limit_reached
        end

        # Track current state before transition
        old_state = @conversation.state

        current_deepening_turn_count = @conversation.meta&.dig("deepening_turn_count").to_i

        # Determine next state (using current deepening count)
        next_state = @state_machine.determine_next_state(user_message, current_deepening_turn_count)

        updated_deepening_turn_count = current_deepening_turn_count
        if next_state == "deepening"
          updated_deepening_turn_count = (old_state == "deepening") ? current_deepening_turn_count + 1 : 1
        end

        # Update conversation state
        @conversation.update!(
          state: next_state,
          meta: @conversation.meta.merge("deepening_turn_count" => updated_deepening_turn_count)
        )

        # Generate assistant response
        assistant_content = @response_generator.generate_response(
          next_state,
          user_message,
          updated_deepening_turn_count
        )

        debug_meta = if debug_enabled?
          {
            "debug" => {
              "state" => next_state,
              "user_turn_count" => @conversation.messages.where(role: 0).count.to_i,
              "max_turns" => (@project.limits.dig("max_turns") || 12).to_i,
              "deepening_turn_count" => updated_deepening_turn_count.to_i,
              "max_deep" => (@project.limits.dig("max_deep") || 5).to_i
            }
          }
        else
          {}
        end

        # Create assistant message
        @conversation.messages.create!(
          role: 1, # assistant
          content: assistant_content,
          meta: debug_meta
        )

        # Check if conversation is complete
        if next_state == "done"
          handle_conversation_completion
        end

        assistant_content
      rescue LLM::Client::OpenAI::OpenAIError => e
        Rails.logger.error "LLM error, switching to fallback mode: #{e.message}"
        # Switch to fallback mode for OpenAI errors even in test environment
        Interview::FallbackOrchestrator.new(@conversation).process_user_message(user_message)
      rescue => e
        if Rails.env.test?
          raise e  # Re-raise other exceptions in test environment for debugging
        else
          Rails.logger.error "LLM error, switching to fallback mode: #{e.message}"
          # Switch to fallback mode
          Interview::FallbackOrchestrator.new(@conversation).process_user_message(user_message)
        end
      end
    end

    private

    def debug_enabled?
      ENV["INTERVIEW_DEBUG"].to_s == "true" || @conversation.meta&.dig("debug_mode") == true
    end

    def handle_turn_limit_reached
      # Mark conversation as finished if turn limit reached
      @conversation.update!(finished_at: Time.current) unless @conversation.finished_at.present?

      # Create a final assistant message indicating completion
      @conversation.messages.create!(
        role: 1, # assistant
        content: "ご協力いただきありがとうございました。インタビューを終了します。"
      )

      # Enqueue analysis job for finished conversation
      AnalyzeConversationJob.perform_later(@conversation.id)

      "ご協力いただきありがとうございました。インタビューを終了します。"
    end

    def handle_conversation_completion
      @conversation.update!(finished_at: Time.current)

      # Enqueue analysis job for finished conversation
      AnalyzeConversationJob.perform_later(@conversation.id)
    end

    def default_llm_client
      if Rails.env.test?
        require_relative "../llm/client/fake"
        LLM::Client::Fake.new
      else
        require_relative "../llm/client/openai"
        LLM::Client::OpenAI.new
      end
    end

    def fallback_mode?
      @conversation.meta&.dig("fallback_mode") == true
    end
  end
end
