module Interview
  class StreamingOrchestrator
    def initialize(conversation, llm_client: nil)
      @conversation = conversation
      @project = conversation.project
      @llm_client = llm_client || (Rails.env.test? ? test_llm_client : LLM::Client::OpenAI.new)
      @prompt_builder = Interview::PromptBuilder.new(@project)
      @broadcast_manager = Interview::BroadcastManager.new(@conversation)
    end

    def process_user_message_with_streaming(user_message)
      # Check turn limit before processing
      user_turn_count = @conversation.messages.where(role: 0).count.to_i
      max_turns = (@project.limits.dig("max_turns") || 12).to_i

      if user_turn_count >= max_turns
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

        # Check if project should be auto-closed
        @conversation.project.check_and_auto_close!

        return "ご協力いただきありがとうございました。インタビューを終了します。"
      end

      # Determine next state
      next_state = determine_next_state(user_message)
      @conversation.update!(state: next_state)

      # Build messages for LLM
      messages = build_conversation_history
      system_prompt = @prompt_builder.system_prompt
      behavior_prompt = @prompt_builder.behavior_prompt_for_state(next_state)

      # Handle special prompts that need interpolation
      if next_state == "summary_check"
        summary = generate_conversation_summary
        behavior_prompt = behavior_prompt.gsub("{summary}", summary)
      elsif next_state == "recommend"
        most_important = identify_most_important_pain_point
        behavior_prompt = behavior_prompt.gsub("{most_important}", most_important)
      end

      # Prepare streaming
      accumulated_content = ""
      assistant_message = nil

      # Stream the response
      @llm_client.stream_chat(
        messages: build_llm_messages(system_prompt, behavior_prompt, messages, user_message.content)
      ) do |chunk|
        accumulated_content += chunk

        # Create assistant message on first chunk
        if assistant_message.nil?
          assistant_message = @conversation.messages.create!(
            role: 1, # assistant
            content: chunk
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

      # Final update with complete content
      if assistant_message
        assistant_message.update!(content: accumulated_content)
        @broadcast_manager.broadcast_final_update
      end

      # Check if conversation is complete
      if next_state == "done"
        @conversation.update!(finished_at: Time.current)
      end

      accumulated_content
    end

    private

    def determine_next_state(user_message)
      # Same logic as regular orchestrator
      current_state = @conversation.state
      max_deep = @project.limits.dig("max_deep") || 2

      case current_state
      when "intro"
        # Stay in intro for the initial system message, move to enumerate after user's first real response
        if user_message.content == "[インタビュー開始]"
          "intro"  # Stay in intro state for initial greeting
        else
          "enumerate"  # Move to enumerate after user's first response
        end
      when "enumerate"
        pain_points = extract_pain_points_from_conversation
        if pain_points.length >= 3 || user_indicates_completion?(user_message.content)
          "recommend"
        else
          "enumerate"
        end
      when "recommend"
        "choose"
      when "choose"
        "deepening"
      when "deepening"
        deepening_turns = count_deepening_turns
        if deepening_turns >= max_deep
          "summary_check"
        else
          "deepening"
        end
      when "summary_check"
        "done"
      else
        "done"
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

    def build_llm_messages(system_prompt, behavior_prompt, conversation_history, user_message)
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

      messages << { role: "user", content: user_message }

      messages
    end

    def extract_pain_points_from_conversation
      user_messages = @conversation.messages.where(role: 0).pluck(:content)
      user_messages.reject { |msg| msg == "[スキップ]" }
    end

    def user_indicates_completion?(content)
      completion_indicators = [ "以上", "それだけ", "終わり", "ない", "特にない" ]
      completion_indicators.any? { |indicator| content.include?(indicator) }
    end

    def count_deepening_turns
      messages_since_deepening = @conversation.messages.where(role: 0)
                                                    .where("created_at > ?", 5.minutes.ago)
                                                    .count
      # Ensure we're working with integers to avoid comparison errors
      count_value = messages_since_deepening.to_i
      [ count_value - 1, 0 ].max
    end

    def identify_most_important_pain_point
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

    def test_llm_client
      Class.new do
        def stream_chat(messages:, **opts, &block)
          # Check if we should simulate an error for testing
          if ENV["SIMULATE_LLM_ERROR"] == "true"
            raise LLM::Client::OpenAI::OpenAIError.new("Simulated error for testing")
          end

          # Return a mock response for tests
          response = "Test response from assistant"

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
      end.new
    end
  end
end
