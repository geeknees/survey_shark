# ABOUTME: Integration tests for conversation message flow and progress rendering.
# ABOUTME: Ensures controller endpoints reflect remaining turns correctly.
require "test_helper"

class ConversationsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = projects(:one)
    @participant = participants(:one)
    @conversation = conversations(:one)
  end

  test "should show conversation" do
    get conversation_path(@conversation)
    assert_response :success
    assert_select "h2", "インタビュー"
    assert_select "#messages"
    assert_select "textarea[name='content']"
  end

  test "should render dynamic quick replies for summary check state" do
    @conversation.update!(state: "summary_check")

    get conversation_path(@conversation)
    assert_response :success

    assert_select "#quick_replies button", count: 3
    assert_select "#quick_replies button", text: "はい、合っています"
    assert_select "#quick_replies button", text: "少し違います"
    assert_select "#quick_replies button", text: "この点を修正します"
  end

  test "should create user message" do
    assert_difference "Message.count", 1 do
      post create_message_conversation_path(@conversation), params: { content: "Hello world" }
    end
    assert_redirected_to conversation_path(@conversation)

    message = Message.last
    assert_equal "Hello world", message.content
    assert_equal "user", message.role
    assert_equal @conversation, message.conversation
  end

  test "should not create message with blank content" do
    assert_no_difference "Message.count" do
      post create_message_conversation_path(@conversation), params: { content: "   " }
    end
    assert_redirected_to conversation_path(@conversation)
  end

  test "should truncate long messages to 500 characters" do
    long_content = "a" * 600
    post create_message_conversation_path(@conversation), params: { content: long_content }

    message = Message.last
    assert_equal 500, message.content.length
  end

  test "should create skip message" do
    assert_difference "Message.count", 1 do
      post skip_conversation_path(@conversation)
    end
    assert_redirected_to conversation_path(@conversation)

    message = Message.last
    assert_equal "[スキップ]", message.content
    assert_equal "user", message.role
  end

  test "should show progress and remaining turns" do
    # Create some user messages
    3.times { |i| @conversation.messages.create!(role: 0, content: "Message #{i}") }

    get conversation_path(@conversation)
    assert_response :success

    # Check that progress shows (assuming default max_turns is 12)
    assert_select "div", text: /残り 9 ターン/
  end

  test "should render messages partial via messages endpoint" do
    # Seed a couple of messages so the partial has content
    m1 = @conversation.messages.create!(role: 0, content: "Hello")
    m2 = @conversation.messages.create!(role: 1, content: "Hi there")

    get messages_conversation_path(@conversation)
    assert_response :success

    # Should contain the messages container and individual message DOM ids
    assert_includes @response.body, 'id="conversation_progress"'
    assert_match(/残り 11 ターン/, @response.body)
    assert_includes @response.body, 'id="messages"'
    assert_includes @response.body, "message_#{m1.id}"
    assert_includes @response.body, "message_#{m2.id}"
  end

  test "messages endpoint should include quick replies for current state" do
    @conversation.update!(state: "summary_check")

    get messages_conversation_path(@conversation)
    assert_response :success

    assert_includes @response.body, 'id="quick_replies"'
    assert_includes @response.body, "はい、合っています"
    assert_includes @response.body, "少し違います"
    assert_includes @response.body, "この点を修正します"
  end

  test "messages endpoint includes completion status for finished conversation" do
    @conversation.update!(state: "done", finished_at: Time.current)

    get messages_conversation_path(@conversation)
    assert_response :success

    assert_includes @response.body, 'id="conversation_status"'
    assert_includes @response.body, 'data-finished="true"'
    assert_includes @response.body, project_thank_you_path(@conversation.project)
  end

  test "should not create message when max turns reached and mark finished" do
    # Exhaust user turns to the limit
    max_turns = (@conversation.project.limits.dig("max_turns") || 12).to_i
    max_turns.times { |i| @conversation.messages.create!(role: 0, content: "User #{i}") }

    assert_no_difference "Message.count" do
      post create_message_conversation_path(@conversation), params: { content: "One more" }
    end
    assert_redirected_to conversation_path(@conversation)

    # Controller should mark as finished when limit hit
    assert_not_nil @conversation.reload.finished_at
  end
end
