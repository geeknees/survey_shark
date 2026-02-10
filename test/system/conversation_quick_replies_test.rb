# ABOUTME: System tests for dynamic quick replies in the conversation composer.
# ABOUTME: Ensures quick-reply chips reflect state and can populate the textarea.
require "application_system_test_case"

class ConversationQuickRepliesTest < ApplicationSystemTestCase
  test "summary check quick reply fills composer textarea" do
    conversation = conversations(:one)
    conversation.update!(state: "summary_check")

    visit conversation_path(conversation)

    assert_selector "#quick_replies button", count: 3
    click_button "少し違います"

    assert_field "content", with: "少し違います"
  end
end
