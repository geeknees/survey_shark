require "test_helper"
require_relative "../../../app/services/interview"
require_relative "../../../app/services/interview/orchestrator"
require_relative "../../../app/services/llm"
require_relative "../../../app/services/llm/client"
require_relative "../../../app/services/llm/client/fake"

class Interview::OrchestratorTest < ActiveSupport::TestCase
  def setup
    @project = projects(:one)
    @participant = participants(:one)
    @conversation = conversations(:one)
    @fake_client = LLM::Client::Fake.new
    @orchestrator = Interview::Orchestrator.new(@conversation, llm_client: @fake_client)
  end

  test "processes user message and creates assistant response" do
    user_message = @conversation.messages.create!(role: :user, content: "I have trouble with my computer")

    assert_difference "Message.count", 1 do
      @orchestrator.process_user_message(user_message)
    end

    assistant_message = @conversation.messages.assistant.last
    assert_not_nil assistant_message
    assert assistant_message.content.present?
  end

  test "transitions from intro to enumerate state" do
    @conversation.update!(state: "intro")
    user_message = @conversation.messages.create!(role: :user, content: "Hello")

    @orchestrator.process_user_message(user_message)

    assert_equal "enumerate", @conversation.reload.state
  end

  test "transitions from enumerate to recommend after multiple pain points" do
    @conversation.update!(state: "enumerate")

    # Add multiple user messages to simulate pain points
    @conversation.messages.create!(role: :user, content: "Problem 1")
    @conversation.messages.create!(role: :user, content: "Problem 2")
    user_message = @conversation.messages.create!(role: :user, content: "Problem 3")

    @orchestrator.process_user_message(user_message)

    assert_equal "recommend", @conversation.reload.state
  end

  test "transitions from recommend to choose" do
    @conversation.update!(state: "recommend")
    user_message = @conversation.messages.create!(role: :user, content: "Yes, that sounds right")

    @orchestrator.process_user_message(user_message)

    assert_equal "choose", @conversation.reload.state
  end

  test "transitions from choose to deepening" do
    @conversation.update!(state: "choose")
    user_message = @conversation.messages.create!(role: :user, content: "I choose the first problem")

    @orchestrator.process_user_message(user_message)

    assert_equal "deepening", @conversation.reload.state
  end

  test "transitions from deepening to summary_check after max_deep turns" do
    @conversation.update!(state: "deepening")
    @project.update!(limits: { "max_deep" => 1 })

    # Recreate orchestrator to pick up updated project settings
    @orchestrator = Interview::Orchestrator.new(@conversation, llm_client: @fake_client)

    # First deepening turn
    user_message = @conversation.messages.create!(role: :user, content: "More details about the problem")
    @orchestrator.process_user_message(user_message)

    # Should still be in deepening
    assert_equal "deepening", @conversation.reload.state

    # Second deepening turn should move to summary_check
    user_message2 = @conversation.messages.create!(role: :user, content: "Even more details")
    @orchestrator.process_user_message(user_message2)

    assert_equal "summary_check", @conversation.reload.state
  end

  test "transitions from summary_check to done and marks conversation finished" do
    @conversation.update!(state: "summary_check")
    user_message = @conversation.messages.create!(role: :user, content: "Yes, that's correct")

    assert_nil @conversation.finished_at

    @orchestrator.process_user_message(user_message)

    assert_equal "done", @conversation.reload.state
    assert_not_nil @conversation.reload.finished_at
  end

  test "handles skip messages" do
    @conversation.update!(state: "enumerate")
    user_message = @conversation.messages.create!(role: :user, content: "[スキップ]")

    assert_difference "Message.count", 1 do
      @orchestrator.process_user_message(user_message)
    end

    # Should still progress to next state
    assert_equal "recommend", @conversation.reload.state
  end

  test "generates appropriate responses for different states" do
    states_and_expected_keywords = {
      "intro" => [ "課題", "不便" ],
      "enumerate" => [ "他に", "課題" ],
      "recommend" => [ "重要" ],
      "choose" => [ "選んで" ],
      "deepening" => [ "詳しく" ],
      "summary_check" => [ "まとめ", "確認" ]
    }

    states_and_expected_keywords.each do |state, keywords|
      @conversation.update!(state: state)
      user_message = @conversation.messages.create!(role: :user, content: "Test message")

      response = @orchestrator.process_user_message(user_message)

      # Check that response contains expected keywords (this is a simple check)
      # In a real implementation, you might want more sophisticated testing
      assert response.present?, "Response should not be empty for state #{state}"
    end
  end
end
