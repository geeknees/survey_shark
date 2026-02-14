# ABOUTME: View test for conversation progress wrapper and remaining turns text.
# ABOUTME: Ensures the progress partial renders the expected DOM structure.
require "test_helper"

class ConversationsProgressPartialTest < ActionView::TestCase
  fixtures :all

  test "renders progress wrapper with remaining turns" do
    conversation = conversations(:one)

    render partial: "conversations/progress", locals: { conversation: conversation }

    assert_select "div#conversation_progress"
    assert_select "div", text: /残り 12 ターン/
  end

  test "caps progress bar width at 100 percent when user turns exceed limit" do
    conversation = conversations(:one)
    conversation.project.update!(limits: conversation.project.limits.merge("max_turns" => 1))
    3.times { |i| conversation.messages.create!(role: :user, content: "over #{i}") }

    render partial: "conversations/progress", locals: { conversation: conversation }

    assert_match(/style="width: 100(\.0)?%"/, rendered)
  end
end
