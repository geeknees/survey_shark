module Interview
  # Manages conversation state transitions and determines next state based on user input
  class StateMachine
    STATES = %w[intro enumerate recommend choose deepening summary_check done].freeze

    def initialize(conversation, project)
      @conversation = conversation
      @project = project
    end

    # Determine the next state based on current state and user message
    def determine_next_state(user_message, deepening_turn_count)
      current_state = @conversation.state
      # Reload project to get latest limits
      @project.reload
      max_deep = @project.limits.dig("max_deep") || 5

      case current_state
      when "intro"
        handle_intro_state(user_message)
      when "enumerate"
        handle_enumerate_state(user_message)
      when "recommend"
        "choose"
      when "choose"
        "deepening"
      when "deepening"
        handle_deepening_state(deepening_turn_count, max_deep)
      when "summary_check"
        "done"
      else
        "done"
      end
    end

    # Check if conversation has reached turn limit
    def turn_limit_reached?
      user_turn_count = @conversation.messages.where(role: 0).count.to_i
      max_turns = (@project.limits.dig("max_turns") || 12).to_i
      user_turn_count >= max_turns
    end

    private

    def handle_intro_state(user_message)
      # Stay in intro for the initial system message, move to enumerate after user's first real response
      if user_message.content == "[インタビュー開始]"
        "intro"  # Stay in intro state for initial greeting
      else
        "enumerate"  # Move to enumerate after user's first response
      end
    end

    def handle_enumerate_state(user_message)
      # Check if we have enough pain points (up to 3) or user indicates they're done
      pain_points = extract_pain_points_from_conversation
      if pain_points.length >= 3 || user_indicates_completion?(user_message.content) || user_message.content == "[スキップ]"
        "recommend"
      else
        "enumerate"
      end
    end

    def handle_deepening_state(deepening_turn_count, max_deep)
      if deepening_turn_count >= max_deep
        "summary_check"
      else
        "deepening"
      end
    end

    def extract_pain_points_from_conversation
      # Simple extraction - in real implementation this would be more sophisticated
      user_messages = @conversation.messages.where(role: 0).pluck(:content)
      # Exclude system messages, skip messages, and completion indicators
      user_messages.reject { |msg|
        msg == "[スキップ]" ||
        msg == "[インタビュー開始]" ||
        user_indicates_completion?(msg)
      }
    end

    def user_indicates_completion?(content)
      completion_indicators = [ "以上", "それだけ", "終わり", "ない", "特にない" ]
      completion_indicators.any? { |indicator| content.include?(indicator) }
    end
  end
end
