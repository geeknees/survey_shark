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
    user_message = @conversation.messages.create!(role: :user, content: "Describe a problem")
    response = @orchestrator.process_user_message_with_streaming(user_message)
    assert response.present?
    assistant_message = @conversation.messages.assistant.last
    assert assistant_message.present?
    assert_equal assistant_message.content, response
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
