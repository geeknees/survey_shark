# ABOUTME: Tests conversation state machine helpers for active/finished states.
# ABOUTME: Covers fallback and turn limit behavior across valid states.
require "test_helper"

class ConversationStateMachineTest < ActiveSupport::TestCase
  setup do
    @project = projects(:one)
    @conversation = conversations(:one)
  end

  test "in_state? returns true when conversation is in specified state" do
    @conversation.update!(state: "intro")
    assert @conversation.in_state?("intro")
    assert @conversation.in_state?(:intro)
    assert_not @conversation.in_state?("deepening")
  end

  test "finished? returns true when conversation has finished_at set" do
    @conversation.update!(finished_at: Time.current)
    assert @conversation.finished?
  end

  test "finished? returns true when conversation is in done state" do
    @conversation.update!(state: "done")
    assert @conversation.finished?
  end

  test "active? returns true for active conversations" do
    @conversation.update!(state: "deepening", finished_at: nil)
    assert @conversation.active?
  end

  test "active? returns false for finished conversations" do
    @conversation.update!(state: "done", finished_at: Time.current)
    assert_not @conversation.active?
  end

  test "active? returns false for fallback conversations" do
    @conversation.update!(state: "fallback")
    assert_not @conversation.active?
  end

  test "fallback_mode? returns true when state is fallback" do
    @conversation.update!(state: "fallback")
    assert @conversation.fallback_mode?
  end

  test "can_accept_messages? returns true when active and not at turn limit" do
    @conversation.update!(state: "deepening", finished_at: nil)
    assert @conversation.can_accept_messages?
  end

  test "can_accept_messages? returns false when finished" do
    @conversation.update!(finished_at: Time.current)
    assert_not @conversation.can_accept_messages?
  end

  test "at_turn_limit? returns true when remaining turns is zero or less" do
    @project.update!(limits: { "max_turns" => 1 })
    @conversation.messages.create!(role: :user, content: "Test message")
    assert @conversation.at_turn_limit?
  end
end
