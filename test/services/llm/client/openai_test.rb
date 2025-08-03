require "test_helper"
require "webmock/minitest"
require_relative "../../../../app/services/llm"
require_relative "../../../../app/services/llm/client"
require_relative "../../../../app/services/llm/client/base"
require_relative "../../../../app/services/llm/client/openai"

class LLM::Client::OpenAITest < ActiveSupport::TestCase
  def setup
    @api_key = "test-api-key"
    @client = LLM::Client::OpenAI.new(api_key: @api_key)
    WebMock.enable!
  end

  def teardown
    WebMock.disable!
  end

  test "initializes with API key from ENV" do
    ENV["OPENAI_API_KEY"] = "env-api-key"
    client = LLM::Client::OpenAI.new
    assert_equal "env-api-key", client.instance_variable_get(:@api_key)
  ensure
    ENV.delete("OPENAI_API_KEY")
  end

  test "raises error without API key" do
    ENV.delete("OPENAI_API_KEY")
    assert_raises(ArgumentError) do
      LLM::Client::OpenAI.new
    end
  end

  test "generates response successfully" do
    stub_successful_response("Hello, how can I help you today?")

    response = @client.generate_response(
      system_prompt: "You are helpful",
      behavior_prompt: "Be polite",
      conversation_history: [],
      user_message: "Hello"
    )

    assert_equal "Hello, how can I help you today?", response
  end

  test "truncates long responses" do
    long_response = "a" * 500 # Longer than 400 char limit
    stub_successful_response(long_response)

    response = @client.generate_response(
      system_prompt: "You are helpful",
      behavior_prompt: "Be polite",
      conversation_history: [],
      user_message: "Hello"
    )

    assert response.length <= 400
  end

  test "truncates at sentence boundary when possible" do
    response_with_sentences = "This is the first sentence。This is a very long second sentence that goes on and on and should be truncated" + "a" * 300 + "。This is the third sentence。"
    stub_successful_response(response_with_sentences)

    response = @client.generate_response(
      system_prompt: "You are helpful",
      behavior_prompt: "Be polite",
      conversation_history: [],
      user_message: "Hello"
    )

    assert response.length <= 400
    assert response.end_with?("。")
  end

  test "retries on API error" do
    # First request fails
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(status: 500, body: '{"error": "Internal server error"}')
      .then
      .to_return(
        status: 200,
        body: {
          choices: [ { message: { content: "Success after retry" } } ]
        }.to_json
      )

    response = @client.generate_response(
      system_prompt: "You are helpful",
      behavior_prompt: "Be polite",
      conversation_history: [],
      user_message: "Hello"
    )

    assert_equal "Success after retry", response
  end

  test "raises error after retry limit" do
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(status: 500, body: '{"error": "Internal server error"}')
      .times(2) # Initial request + 1 retry

    assert_raises(LLM::Client::OpenAI::OpenAIError) do
      @client.generate_response(
        system_prompt: "You are helpful",
        behavior_prompt: "Be polite",
        conversation_history: [],
        user_message: "Hello"
      )
    end
  end

  test "handles network timeout" do
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_timeout
      .then
      .to_return(
        status: 200,
        body: {
          choices: [ { message: { content: "Success after timeout retry" } } ]
        }.to_json
      )

    response = @client.generate_response(
      system_prompt: "You are helpful",
      behavior_prompt: "Be polite",
      conversation_history: [],
      user_message: "Hello"
    )

    assert_equal "Success after timeout retry", response
  end

  test "stream_chat without block returns full response" do
    stub_successful_response("Streaming response")

    response = @client.stream_chat(messages: [ { role: "user", content: "Hello" } ])

    assert_equal "Streaming response", response
  end

  test "stream_chat with block does not crash" do
    # This test ensures streaming implementation doesn't crash the application
    stub_successful_response("Response content")

    assert_nothing_raised do
      @client.stream_chat(messages: [ { role: "user", content: "Hello" } ]) do |chunk|
        # Just make sure we can handle whatever chunks come through
      end
    end
  end

  private

  def stub_successful_response(content)
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(
        status: 200,
        body: {
          choices: [ { message: { content: content } } ]
        }.to_json
      )
  end
end
