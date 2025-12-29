module Interview
  # Manages turn counting and state-specific turn logic
  class TurnManager
    def initialize(conversation)
      @conversation = conversation
      @deepening_turn_count = 0
    end

    attr_reader :deepening_turn_count

    # Update deepening turn count based on state transition
    def track_state_transition(old_state, new_state)
      if old_state == "deepening" && new_state == "deepening"
        @deepening_turn_count += 1
      elsif new_state == "deepening" && old_state != "deepening"
        @deepening_turn_count = 1
      end
    end

    # Get total user message count
    def user_message_count
      @conversation.messages.where(role: 0).count.to_i
    end
  end
end
