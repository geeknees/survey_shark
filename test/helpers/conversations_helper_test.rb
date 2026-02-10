# ABOUTME: Unit tests for conversation quick-reply suggestion selection.
# ABOUTME: Verifies state-aware and context-aware quick-reply generation.
require "test_helper"

class ConversationsHelperTest < ActionView::TestCase
  fixtures :all

  test "returns summary check quick replies with correction prompt" do
    conversation = conversations(:one)
    conversation.update!(state: "summary_check")

    suggestions = quick_reply_suggestions(conversation)

    assert_equal 3, suggestions.size
    assert_includes suggestions, "はい、合っています"
    assert_includes suggestions, "少し違います"
    assert_includes suggestions, "この点を修正します"
  end

  test "adds detail-oriented suggestion when last user message is short" do
    conversation = conversations(:one)
    conversation.update!(state: "deepening")
    conversation.messages.create!(role: :user, content: "短い")

    suggestions = quick_reply_suggestions(conversation)

    assert_includes suggestions, "もう少し具体的に答えます"
    assert_operator suggestions.size, :<=, 3
  end

  test "adds supportive suggestion when user says they do not know" do
    conversation = conversations(:one)
    conversation.update!(state: "deepening")
    conversation.messages.create!(role: :user, content: "わからないです")

    suggestions = quick_reply_suggestions(conversation)

    assert_includes suggestions, "思い出せる範囲で答えます"
    assert_operator suggestions.size, :<=, 3
  end
end
