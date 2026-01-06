# ABOUTME: System test for progress display updates across page loads.
# ABOUTME: Confirms remaining turns reflect new user messages.
require "application_system_test_case"

class ConversationProgressTest < ApplicationSystemTestCase
  test "progress updates after new user message on reload" do
    conversation = conversations(:one)

    visit conversation_path(conversation)
    assert_selector "#conversation_progress", text: "残り 12 ターン"

    conversation.messages.create!(role: 0, content: "First message")

    visit conversation_path(conversation)
    assert_selector "#conversation_progress", text: "残り 11 ターン"
  end
end
