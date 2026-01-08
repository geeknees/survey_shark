# ABOUTME: Manages interview state transitions based on conversation context.
# ABOUTME: Encapsulates rules for moving between interview phases.
module Interview
  # Manages conversation state transitions and determines next state based on user input
  class StateMachine
    STATES = %w[intro deepening must_ask summary_check done].freeze

    def initialize(conversation, project)
      @conversation = conversation
      @project = project
    end

    # Determine the next state based on current state and user message
    def determine_next_state(user_message, deepening_turn_count)
      current_state = @conversation.state
      # Reload project to get latest limits
      @project.reload
      max_deep = limit_value("max_deep", 5).to_i

      case current_state
      when "intro"
        handle_intro_state(user_message)
      when "deepening"
        handle_deepening_state(deepening_turn_count, max_deep)
      when "must_ask"
        handle_must_ask_state(user_message)
      when "summary_check"
        "done"
      else
        "done"
      end
    end

    # Check if conversation has reached turn limit
    def turn_limit_reached?
      user_turn_count = @conversation.messages.where(role: 0).count.to_i
      max_turns = limit_value("max_turns", 12).to_i
      user_turn_count >= max_turns
    end

    private

    def handle_intro_state(user_message)
      # Stay in intro for the initial system message, move to deepening after user's first real response
      if user_message.content == "[インタビュー開始]"
        "intro"  # Stay in intro state for initial greeting
      else
        "deepening"
      end
    end

    def handle_deepening_state(deepening_turn_count, max_deep)
      if deepening_turn_count >= max_deep
        must_ask_manager = Interview::MustAskManager.new(@project, @conversation.meta)
        return "must_ask" if must_ask_manager.pending?

        "summary_check"
      else
        "deepening"
      end
    end

    def handle_must_ask_state(user_message)
      must_ask_manager = Interview::MustAskManager.new(@project, @conversation.meta)
      must_ask_manager.next_state_after_answer(user_message.content)
    end

    def limit_value(key, default)
      limits = @project.limits.is_a?(Hash) ? @project.limits : {}
      limits[key] || limits[key.to_sym] || default
    end
  end
end
