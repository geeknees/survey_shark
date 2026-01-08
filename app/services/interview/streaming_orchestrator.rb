# ABOUTME: Streams assistant responses and updates conversation state in real time.
# ABOUTME: Adds must-ask handling to streaming flow and turn limit checks.
module Interview
  class StreamingOrchestrator
    def initialize(conversation, llm_client: nil)
      @conversation = conversation
      @project = conversation.project
      @llm_client = llm_client || (Rails.env.test? ? test_llm_client : LLM::Client::OpenAI.new)
      @prompt_builder = Interview::PromptBuilder.new(@project)
      @state_machine = Interview::StateMachine.new(@conversation, @project)
      @broadcast_manager = Interview::BroadcastManager.new(@conversation)
    end

    def process_user_message_with_streaming(user_message)
      # Check turn limit before processing
      user_turn_count = @conversation.messages.where(role: 0).count.to_i
      max_turns = (@project.limits.dig("max_turns") || 12).to_i

      must_ask_manager = Interview::MustAskManager.new(@project, @conversation.meta)
      if user_turn_count >= max_turns && !must_ask_manager.pending? && !@conversation.in_state?("summary_check")
        # Mark conversation as finished if turn limit reached
        @conversation.update!(finished_at: Time.current) unless @conversation.finished_at.present?

        # Check if project should be auto-closed
        @conversation.project.check_and_auto_close!

        # Create a final assistant message indicating completion
        @conversation.messages.create!(
          role: 1, # assistant
          content: "ご協力いただきありがとうございました。インタビューを終了します。"
        )

        # Broadcast the final message using the broadcast manager
        @broadcast_manager.broadcast_final_update

        # Enqueue analysis job for finished conversation
        AnalyzeConversationJob.perform_later(@conversation.id)

        return "ご協力いただきありがとうございました。インタビューを終了します。"
      end

      # Determine next state (using persisted deepening count)
      old_state = @conversation.state
      current_deepening_turn_count = persisted_deepening_turn_count
      next_state = @state_machine.determine_next_state(user_message, current_deepening_turn_count)

      updated_meta = @conversation.meta || {}
      if old_state == "must_ask"
        updated_meta = must_ask_manager.advance_meta_for_answer(user_message.content)
      elsif next_state == "must_ask"
        updated_meta = must_ask_manager.start_meta
      end

      updated_deepening_turn_count = current_deepening_turn_count
      if next_state == "deepening"
        updated_deepening_turn_count = (old_state == "deepening") ? current_deepening_turn_count + 1 : 1
      end

      @conversation.update!(
        state: next_state,
        meta: updated_meta.merge("deepening_turn_count" => updated_deepening_turn_count)
      )

      messages = build_conversation_history
      system_prompt = @prompt_builder.system_prompt
      behavior_prompt = @prompt_builder.behavior_prompt_for_state_with_context(
        next_state,
        deepening_turn: updated_deepening_turn_count,
        conversation: @conversation
      )

      # Prepare streaming
      accumulated_content = ""
      assistant_message = nil

      debug_meta = debug_enabled? ? build_debug_meta(next_state, updated_deepening_turn_count) : {}

      # Stream the response (and capture non-stream fallback result)
      response_text = @llm_client.stream_chat(
        messages: build_llm_messages(system_prompt, behavior_prompt, messages)
      ) do |chunk|
        accumulated_content += chunk

        # Create assistant message on first chunk
        if assistant_message.nil?
          assistant_message = @conversation.messages.create!(
            role: 1, # assistant
            content: chunk,
            meta: debug_meta
          )
          # Broadcast the new message to the messages list
          Turbo::StreamsChannel.broadcast_append_to(
            @conversation,
            target: "messages",
            partial: "conversations/message",
            locals: { message: assistant_message }
          )
        else
          # Update existing message
          assistant_message.update!(content: accumulated_content)
        end

        # Broadcast the streaming update using the broadcast manager
        @broadcast_manager.broadcast_streaming_update(assistant_message, chunk)
      end

      # Finalize and broadcast
      if assistant_message
        # Streaming path: ensure final content saved and broadcast
        assistant_message.update!(content: accumulated_content)
        @broadcast_manager.broadcast_final_update
      elsif response_text.present?
        # Non-streaming fallback path: create message now and broadcast
        assistant_message = @conversation.messages.create!(
          role: 1,
          content: response_text,
          meta: debug_meta
        )
        @broadcast_manager.broadcast_final_update
        accumulated_content = response_text
      end

      # Check if conversation is complete
      if next_state == "done"
        @conversation.update!(finished_at: Time.current)
      end

      accumulated_content
    end

    private

    def persisted_deepening_turn_count
      @conversation.meta&.dig("deepening_turn_count").to_i
    end

    def build_debug_meta(next_state, deepening_turn_count)
      user_turn_count = @conversation.messages.where(role: 0).count.to_i
      {
        "debug" => {
          "state" => next_state,
          "user_turn_count" => user_turn_count,
          "max_turns" => (@project.limits.dig("max_turns") || 12).to_i,
          "deepening_turn_count" => deepening_turn_count.to_i,
          "max_deep" => (@project.limits.dig("max_deep") || 5).to_i
        }
      }
    end

    def debug_enabled?
      ENV["INTERVIEW_DEBUG"].to_s == "true" || @conversation.meta&.dig("debug_mode") == true
    end

    def build_conversation_history
      @conversation.messages.order(:created_at).map do |message|
        {
          role: message.user? ? "user" : "assistant",
          content: message.content
        }
      end
    end

    def build_llm_messages(system_prompt, behavior_prompt, conversation_history)
      messages = []

      if system_prompt.present?
        messages << { role: "system", content: system_prompt }
      end

      conversation_history.each do |msg|
        messages << { role: msg[:role], content: msg[:content] }
      end

      if behavior_prompt.present?
        messages << { role: "system", content: behavior_prompt }
      end

      messages
    end


    def test_llm_client
      Class.new do
        def initialize
          @call_count = 0
        end

        def stream_chat(messages:, **opts, &block)
          # Check if we should simulate an error for testing
          if ENV["SIMULATE_LLM_ERROR"] == "true"
            raise LLM::Client::OpenAI::OpenAIError.new("Simulated error for testing")
          end

          # Return a mock response for tests
          response = build_response(messages)

          if block_given?
            # Simulate streaming by yielding chunks
            words = response.split(" ")
            words.each_with_index do |word, index|
              chunk = index == words.length - 1 ? word : "#{word} "
              yield(chunk)
            end
          end

          response
        end

        private

        def build_response(messages)
          behavior_prompt = messages.reverse.find { |msg| msg[:role] == "system" }&.dig(:content).to_s
          must_ask_match = behavior_prompt.match(/必ず聞く項目:\s*([^\n]+)/)
          return "次に、「#{must_ask_match[1]}」について教えてください。" if must_ask_match

          @call_count += 1
          "Test response from assistant #{@call_count}"
        end
      end.new
    end
  end
end
