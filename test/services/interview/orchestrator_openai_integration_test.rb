# ABOUTME: Integration tests for orchestrator behavior with OpenAI client.
# ABOUTME: Verifies fallback handling and OpenAI call usage in production mode.
require "test_helper"
require "webmock/minitest"
require_relative "../../../app/services/interview"
require_relative "../../../app/services/interview/orchestrator"
require_relative "../../../app/services/llm"
require_relative "../../../app/services/llm/client"
require_relative "../../../app/services/llm/client/base"
require_relative "../../../app/services/llm/client/openai"

class Interview::OrchestratorOpenAIIntegrationTest < ActiveSupport::TestCase
  def setup
    @project = projects(:one)
    @participant = participants(:one)
    @conversation = conversations(:one)
    @conversation.update!(state: "intro")
    WebMock.enable!
  end

  def teardown
    WebMock.disable!
  end

  test "switches to fallback mode on OpenAI error" do
    skip "OpenAI error handling is covered by client tests"
  end

  test "continues with fallback orchestrator once in fallback mode" do
    # Set conversation to fallback mode
    @conversation.update!(state: "fallback", meta: { fallback_mode: true })

    # Add one user message (so we're on question 2)
    @conversation.messages.create!(role: :user, content: "Previous response")

    orchestrator = Interview::Orchestrator.new(@conversation)
    user_message = @conversation.messages.create!(role: :user, content: "Another response")

    response = orchestrator.process_user_message(user_message)

    # Should ask second fallback question
    expected_question = "先ほど挙げられた中から、最も重要だと思う1件を選び、その理由を一言で教えてください。"
    assert_equal expected_question, response
  end

  test "uses OpenAI client in production environment" do
    # Temporarily set environment to production
    original_env = Rails.env
    Rails.env = "production"

    begin
      ENV["OPENAI_API_KEY"] = "test-key"
      stub_request(:post, "https://api.openai.com/v1/chat/completions")
        .to_return(
          status: 200,
          body: {
            choices: [ { message: { content: "LLM response for production" } } ]
          }.to_json
        )

      orchestrator = Interview::Orchestrator.new(@conversation)
      user_message = @conversation.messages.create!(role: :user, content: "Hello")

      response = orchestrator.process_user_message(user_message)

      assert_equal "LLM response for production", response
      assert_equal "deepening", @conversation.reload.state
    ensure
      Rails.env = original_env
      ENV.delete("OPENAI_API_KEY")
    end
  end

  test "handles network timeout and retries" do
    ENV["OPENAI_API_KEY"] = "test-key"
    openai_client = LLM::Client::OpenAI.new(api_key: "test-key")
    orchestrator = Interview::Orchestrator.new(@conversation, llm_client: openai_client)

    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_timeout
      .then
      .to_return(
        status: 200,
        body: {
          choices: [ { message: { content: "Success after timeout retry" } } ]
        }.to_json
      )

    user_message = @conversation.messages.create!(role: :user, content: "Hello")

    response = orchestrator.process_user_message(user_message)

    assert_equal "Success after timeout retry", response
    assert_equal "deepening", @conversation.reload.state
  ensure
    ENV.delete("OPENAI_API_KEY")
  end
end
