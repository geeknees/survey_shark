require "test_helper"
require_relative "../../../app/services/interview"
require_relative "../../../app/services/interview/fallback_orchestrator"

class Interview::FallbackOrchestratorTest < ActiveSupport::TestCase
  def setup
    @project = projects(:one)
    @participant = participants(:one)
    @conversation = conversations(:one)
    @conversation.update!(state: "fallback", meta: { fallback_mode: true })
    @orchestrator = Interview::FallbackOrchestrator.new(@conversation)
  end

  test "asks first fallback question" do
    user_message = @conversation.messages.create!(role: :user, content: "Hello")

    response = @orchestrator.process_user_message(user_message)

    expected_question = "最近直面した課題や不便と、その具体的な場面を教えてください。"
    assert_equal expected_question, response

    assistant_message = @conversation.messages.assistant.last
    assert_equal expected_question, assistant_message.content
  end

  test "asks second fallback question after first user response" do
    # First user message
    @conversation.messages.create!(role: :user, content: "I have computer problems")
    user_message = @conversation.messages.create!(role: :user, content: "My computer is slow")

    response = @orchestrator.process_user_message(user_message)

    expected_question = "先ほど挙げられた中から、最も重要だと思う1件を選び、その理由を一言で教えてください。"
    assert_equal expected_question, response
  end

  test "asks third fallback question after second user response" do
    # First two user messages
    @conversation.messages.create!(role: :user, content: "I have computer problems")
    @conversation.messages.create!(role: :user, content: "Computer slowness is most important")
    user_message = @conversation.messages.create!(role: :user, content: "It affects my work")

    response = @orchestrator.process_user_message(user_message)

    expected_question = "今思っていることを書いてください。"
    assert_equal expected_question, response
  end

  test "finishes conversation after third question" do
    # Three user messages (all questions answered)
    @conversation.messages.create!(role: :user, content: "I have computer problems")
    @conversation.messages.create!(role: :user, content: "Computer slowness is most important")
    @conversation.messages.create!(role: :user, content: "It affects my work")
    user_message = @conversation.messages.create!(role: :user, content: "I think we need better computers")

    assert_nil @conversation.finished_at

    response = @orchestrator.process_user_message(user_message)

    expected_response = "ご協力いただき、ありがとうございました。貴重なお話をお聞かせいただけました。"
    assert_equal expected_response, response

    @conversation.reload
    assert_equal "done", @conversation.state
    assert_not_nil @conversation.finished_at
  end

  test "ignores skip messages when counting questions" do
    # Add a skip message - should not count toward question progression
    @conversation.messages.create!(role: :user, content: "[スキップ]")
    user_message = @conversation.messages.create!(role: :user, content: "Real response")

    response = @orchestrator.process_user_message(user_message)

    # Should still ask first question since skip doesn't count
    expected_question = "最近直面した課題や不便と、その具体的な場面を教えてください。"
    assert_equal expected_question, response
  end

  test "marks conversation as using fallback mode" do
    @conversation.update!(meta: {})
    user_message = @conversation.messages.create!(role: :user, content: "Hello")

    @orchestrator.process_user_message(user_message)

    @conversation.reload
    assert_equal "fallback", @conversation.state
    assert_equal true, @conversation.meta["fallback_mode"]
  end
end
