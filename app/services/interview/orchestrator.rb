module Interview
  class Orchestrator
    STATES = %w[intro enumerate recommend choose deepening summary_check done].freeze

    def initialize(conversation, llm_client: nil)
      @conversation = conversation
    @project = conversation.project
    @llm_client = llm_client || default_llm_client
    @prompt_builder = Interview::PromptBuilder.new(@project)
  end

  def process_user_message(user_message)
    # Check if already in fallback mode
    if @conversation.state == "fallback" || fallback_mode?
      return Interview::FallbackOrchestrator.new(@conversation).process_user_message(user_message)
    end

    begin
      # Update conversation state based on current state and user input
      next_state = determine_next_state(user_message)
      @conversation.update!(state: next_state)

      # Generate assistant response
      assistant_content = generate_assistant_response(next_state, user_message)

      # Create assistant message
      @conversation.messages.create!(
        role: 1, # assistant
        content: assistant_content
      )

      # Check if conversation is complete
      if next_state == "done"
        @conversation.update!(finished_at: Time.current)

        # Enqueue analysis job for finished conversation
        AnalyzeConversationJob.perform_later(@conversation.id)

        # Store participant data in session for potential restart
        if @conversation.participant
          session[:participant_age] = @conversation.participant.age
          session[:participant_attributes] = @conversation.participant.custom_attributes
        end
      end

      assistant_content
    rescue LLM::Client::OpenAI::OpenAIError => e
      Rails.logger.error "LLM error, switching to fallback mode: #{e.message}"

      # Switch to fallback mode
      Interview::FallbackOrchestrator.new(@conversation).process_user_message(user_message)
    end
  end

  private

  def determine_next_state(user_message)
    current_state = @conversation.state
    user_turn_count = @conversation.messages.where(role: 0).count
    max_deep = @project.limits.dig("max_deep") || 2

    case current_state
    when "intro"
      # After intro, move to enumerate phase
      "enumerate"
    when "enumerate"
      # Check if we have enough pain points (up to 3) or user indicates they're done
      pain_points = extract_pain_points_from_conversation
      if pain_points.length >= 3 || user_indicates_completion?(user_message.content)
        "recommend"
      else
        "enumerate"
      end
    when "recommend"
      # Move to choose phase after recommendation
      "choose"
    when "choose"
      # After user chooses, start deepening
      "deepening"
    when "deepening"
      # Count deepening turns
      deepening_turns = count_deepening_turns
      if deepening_turns >= max_deep
        "summary_check"
      else
        "deepening"
      end
    when "summary_check"
      # After summary confirmation, we're done
      "done"
    else
      "done"
    end
  end

  def generate_assistant_response(state, user_message)
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

  def build_conversation_history
    @conversation.messages.order(:created_at).map do |message|
      {
        role: message.user? ? "user" : "assistant",
        content: message.content
      }
    end
  end

  def extract_pain_points_from_conversation
    # Simple extraction - in real implementation this would be more sophisticated
    user_messages = @conversation.messages.where(role: 0).pluck(:content)
    user_messages.reject { |msg| msg == "[スキップ]" }
  end

  def user_indicates_completion?(content)
    completion_indicators = [ "以上", "それだけ", "終わり", "ない", "特にない" ]
    completion_indicators.any? { |indicator| content.include?(indicator) }
  end

  def count_deepening_turns
    # Count turns since we entered deepening state
    # This is a simplified implementation
    messages_since_deepening = @conversation.messages.where(role: 0)
                                                   .where("created_at > ?", 5.minutes.ago)
                                                   .count
    [ messages_since_deepening - 1, 0 ].max
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

  def default_llm_client
    if Rails.env.test?
      LLM::Client::Fake.new
    else
      LLM::Client::OpenAI.new
    end
  end

  def fallback_mode?
    @conversation.meta&.dig("fallback_mode") == true
  end
  end
end
