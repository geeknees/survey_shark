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

  test "should create user message" do
    assert_difference "Message.count", 1 do
      post create_message_conversation_path(@conversation), params: { content: "Hello world" }
    end
    assert_redirected_to conversation_path(@conversation)
    
    message = Message.last
    assert_equal "Hello world", message.content
    assert_equal 0, message.role # user
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
    assert_equal 0, message.role # user
  end

  test "should show progress and remaining turns" do
    # Create some user messages
    3.times { |i| @conversation.messages.create!(role: 0, content: "Message #{i}") }
    
    get conversation_path(@conversation)
    assert_response :success
    
    # Check that progress shows (assuming default max_turns is 12)
    assert_select "div", text: /残り 9 ターン/
  end
end