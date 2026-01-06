require "test_helper"
require_relative "../../../app/services/interview/streaming_orchestrator"

class Interview::StreamingOrchestratorTest < ActiveSupport::TestCase
  def setup
    @project = projects(:one)
    @conversation = conversations(:one)
    @conversation.update!(state: "intro")
    @orchestrator = Interview::StreamingOrchestrator.new(@conversation)
  end


  test "streams assistant response (fake client)" do
    @conversation.update!(meta: @conversation.meta.merge("debug_mode" => true))
    user_message = @conversation.messages.create!(role: :user, content: "Describe a problem")
    response = @orchestrator.process_user_message_with_streaming(user_message)
    assert response.present?
    assistant_message = @conversation.messages.assistant.last
    assert assistant_message.present?
    assert_equal assistant_message.content, response

    debug = assistant_message.meta&.dig("debug")
    assert debug.present?
    assert_equal @conversation.reload.state, debug["state"]
    assert debug["user_turn_count"].to_i >= 1
  end

  test "persists deepening turn count across turns" do
    @conversation.update!(state: "choose", meta: {})
    @project.update!(limits: @project.limits.merge("max_deep" => 1))

    first = @conversation.messages.create!(role: :user, content: "I choose X")
    @orchestrator.process_user_message_with_streaming(first)
    assert_equal "deepening", @conversation.reload.state
    assert_equal 1, @conversation.meta["deepening_turn_count"].to_i

    second = @conversation.messages.create!(role: :user, content: "More details")
    @orchestrator.process_user_message_with_streaming(second)
    assert_equal "summary_check", @conversation.reload.state
  end

  test "fallback when ENV SIMULATE_LLM_ERROR is set" do
    ENV["SIMULATE_LLM_ERROR"] = "true"
    user_message = @conversation.messages.create!(role: :user, content: "Trigger error")
    assert_raises(LLM::Client::OpenAI::OpenAIError) do
      @orchestrator.process_user_message_with_streaming(user_message)
    end
  ensure
    ENV.delete("SIMULATE_LLM_ERROR")
  end
end
