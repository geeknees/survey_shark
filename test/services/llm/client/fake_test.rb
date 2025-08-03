require "test_helper"
require_relative "../../../../app/services/llm"
require_relative "../../../../app/services/llm/client"
require_relative "../../../../app/services/llm/client/fake"

class LLM::Client::FakeTest < ActiveSupport::TestCase
  def setup
    @client = LLM::Client::Fake.new
  end

  test "generates response" do
    response = @client.generate_response(
      system_prompt: "You are helpful",
      behavior_prompt: "Be polite",
      conversation_history: [],
      user_message: "Hello"
    )

    assert response.present?
    assert response.is_a?(String)
  end

  test "cycles through responses" do
    responses = [ "First", "Second", "Third" ]
    client = LLM::Client::Fake.new(responses: responses)

    assert_equal "First", client.generate_response(
      system_prompt: "", behavior_prompt: "", conversation_history: [], user_message: ""
    )
    assert_equal "Second", client.generate_response(
      system_prompt: "", behavior_prompt: "", conversation_history: [], user_message: ""
    )
    assert_equal "Third", client.generate_response(
      system_prompt: "", behavior_prompt: "", conversation_history: [], user_message: ""
    )
    # Should cycle back to first
    assert_equal "First", client.generate_response(
      system_prompt: "", behavior_prompt: "", conversation_history: [], user_message: ""
    )
  end

  test "stream_chat yields chunks" do
    chunks = []
    response = @client.stream_chat(messages: [ { role: "user", content: "Hello" } ]) do |chunk|
      chunks << chunk
    end

    assert chunks.any?
    assert_equal response, chunks.join
  end

  test "stream_chat without block returns full response" do
    response = @client.stream_chat(messages: [ { role: "user", content: "Hello" } ])

    assert response.present?
    assert response.is_a?(String)
  end
end
