# ABOUTME: Provides state helpers for conversations and turn limit checks.
# ABOUTME: Defines valid states and derived status helpers.
module ConversationStateMachine
  extend ActiveSupport::Concern

  included do
    # State constants
    VALID_STATES = %w[intro deepening must_ask summary_check done fallback].freeze
  end

  # Check if conversation is in a specific state
  def in_state?(state_name)
    state == state_name.to_s
  end

  # Check if conversation is finished
  def finished?
    finished_at.present? || in_state?("done")
  end

  # Check if conversation is active (not finished and not in fallback)
  def active?
    !finished? && !in_state?("fallback")
  end

  # Check if conversation is in fallback mode
  def fallback_mode?
    in_state?("fallback") || meta&.dig("fallback_mode") == true
  end

  # Check if conversation can accept new messages
  def can_accept_messages?
    active? && !at_turn_limit?
  end

  # Check if conversation is at turn limit
  def at_turn_limit?
    remaining_turns <= 0
  end
end
