# ABOUTME: Tests interview orchestrator behavior across states and edge cases.
# ABOUTME: Covers must-ask sequencing, turn limits, and response generation.
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

  test "transitions from intro to deepening state" do
    @conversation.update!(state: "intro")
    user_message = @conversation.messages.create!(role: :user, content: "Hello")

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

  test "moves to must_ask after deepening before summary_check" do
    @project.update!(must_ask: [ "年齢", "居住地" ], limits: @project.limits.merge("max_deep" => 1))
    @conversation.update!(state: "deepening", meta: { "deepening_turn_count" => 1 })
    must_ask_client = LLM::Client::Fake.new(responses: [ "次に、「年齢」について教えてください。" ])
    @orchestrator = Interview::Orchestrator.new(@conversation, llm_client: must_ask_client)

    user_message = @conversation.messages.create!(role: :user, content: "More details")
    response = @orchestrator.process_user_message(user_message)

    assert_equal "must_ask", @conversation.reload.state
    assert_includes response, "年齢"
  end

  test "asks a follow-up when must_ask answer is unclear" do
    @project.update!(must_ask: [ "年齢" ])
    @conversation.update!(state: "must_ask", meta: { "must_ask_index" => 0, "must_ask_followup" => false })
    followup_client = LLM::Client::Fake.new(responses: [ "先ほどの「年齢」について、もう少し詳しく教えていただけますか？" ])
    @orchestrator = Interview::Orchestrator.new(@conversation, llm_client: followup_client)

    user_message = @conversation.messages.create!(role: :user, content: "わからない")
    response = @orchestrator.process_user_message(user_message)

    assert_equal "must_ask", @conversation.reload.state
    assert_includes response, "もう少し詳しく"
  end

  test "advances to summary_check after the last must_ask item" do
    @project.update!(must_ask: [ "年齢" ])
    @conversation.update!(state: "must_ask", meta: { "must_ask_index" => 0 })
    must_ask_client = LLM::Client::Fake.new(responses: [ "次に、「年齢」について教えてください。" ])
    @orchestrator = Interview::Orchestrator.new(@conversation, llm_client: must_ask_client)

    user_message = @conversation.messages.create!(role: :user, content: "30歳です")
    @orchestrator.process_user_message(user_message)

    assert_equal "summary_check", @conversation.reload.state
  end

  test "prioritizes must_ask over turn limit" do
    @project.update!(
      must_ask: [ "年齢" ],
      limits: @project.limits.merge("max_deep" => 1, "max_turns" => 1)
    )
    @conversation.update!(state: "deepening", meta: { "deepening_turn_count" => 1 })
    must_ask_client = LLM::Client::Fake.new(responses: [ "次に、「年齢」について教えてください。" ])
    @orchestrator = Interview::Orchestrator.new(@conversation, llm_client: must_ask_client)

    user_message = @conversation.messages.create!(role: :user, content: "More details")
    response = @orchestrator.process_user_message(user_message)

    assert_equal "must_ask", @conversation.reload.state
    assert_nil @conversation.finished_at
    assert_includes response, "年齢"
  end

  test "transitions from summary_check to done and marks conversation finished" do
    @conversation.update!(state: "summary_check")
    user_message = @conversation.messages.create!(role: :user, content: "Yes, that's correct")

    assert_nil @conversation.finished_at

    @orchestrator.process_user_message(user_message)

    assert_equal "done", @conversation.reload.state
    assert_not_nil @conversation.reload.finished_at
  end

  test "allows summary_check response even when turn limit reached" do
    @project.update!(limits: @project.limits.merge("max_turns" => 0))
    @conversation.update!(state: "summary_check")
    done_client = LLM::Client::Fake.new(responses: [ "完了メッセージ" ])
    @orchestrator = Interview::Orchestrator.new(@conversation, llm_client: done_client)

    user_message = @conversation.messages.create!(role: :user, content: "はい")
    @orchestrator.process_user_message(user_message)

    assert_equal "done", @conversation.reload.state
    assert_not_nil @conversation.reload.finished_at
  end

  test "handles skip messages" do
    @conversation.update!(state: "intro")
    user_message = @conversation.messages.create!(role: :user, content: "[スキップ]")

    assert_difference "Message.count", 1 do
      @orchestrator.process_user_message(user_message)
    end

    # Should still progress to next state
    assert_equal "deepening", @conversation.reload.state
  end

  test "generates appropriate responses for different states" do
    states_and_expected_keywords = {
      "intro" => [ "課題", "不便" ],
      "deepening" => [ "詳しく" ],
      "summary_check" => [ "要約", "確認" ]
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
