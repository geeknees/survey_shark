require "test_helper"
require "webmock/minitest"

class StreamAssistantResponseJobTest < ActiveJob::TestCase
  def setup
    @conversation = conversations(:one)
    @user_message = @conversation.messages.create!(role: :user, content: "Test message")
    WebMock.enable!
  end

  def teardown
    WebMock.disable!
  end

  test "processes user message with fallback orchestrator when in fallback mode" do
    @conversation.update!(state: "fallback", meta: { fallback_mode: true })

    assert_difference "Message.count", 1 do
      StreamAssistantResponseJob.perform_now(@conversation.id, @user_message.id)
    end

    assistant_message = @conversation.messages.assistant.last
    assert_not_nil assistant_message
    assert assistant_message.content.present?
  end

  test "uses streaming orchestrator for normal conversations" do
    # Stub OpenAI for streaming - simulate streaming response
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(
        status: 200,
        body: "data: {\"choices\":[{\"delta\":{\"content\":\"Streaming \"}}]}\n\ndata: {\"choices\":[{\"delta\":{\"content\":\"response\"}}]}\n\ndata: [DONE]\n\n"
      )

    ENV["OPENAI_API_KEY"] = "test-key"

    begin
      assert_difference "Message.count", 1 do
        StreamAssistantResponseJob.perform_now(@conversation.id, @user_message.id)
      end

      assistant_message = @conversation.messages.assistant.last
      assert_not_nil assistant_message
      assert assistant_message.content.present?
    ensure
      ENV.delete("OPENAI_API_KEY")
    end
  end

  test "falls back to regular orchestrator on OpenAI error" do
    # Stub OpenAI to fail
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(status: 500, body: '{"error": "Internal server error"}')
      .times(2) # Initial + 1 retry

    ENV["OPENAI_API_KEY"] = "test-key"

    begin
      assert_difference "Message.count", 1 do
        StreamAssistantResponseJob.perform_now(@conversation.id, @user_message.id)
      end

      # Should have switched to fallback mode
      @conversation.reload
      assert_equal "fallback", @conversation.state
      assert_equal true, @conversation.meta["fallback_mode"]

      # Should have created assistant message with fallback content
      assistant_message = @conversation.messages.assistant.last
      assert_includes assistant_message.content, "最近直面した課題"
    ensure
      ENV.delete("OPENAI_API_KEY")
    end
  end

  test "handles non-existent conversation gracefully" do
    assert_raises(ActiveRecord::RecordNotFound) do
      StreamAssistantResponseJob.perform_now(999999, @user_message.id)
    end
  end

  test "handles non-existent message gracefully" do
    assert_raises(ActiveRecord::RecordNotFound) do
      StreamAssistantResponseJob.perform_now(@conversation.id, 999999)
    end
  end
end
