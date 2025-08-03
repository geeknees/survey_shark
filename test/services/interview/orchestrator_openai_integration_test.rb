require "test_helper"
require "webmock/minitest"

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
    # Stub OpenAI to fail
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(status: 500, body: '{"error": "Internal server error"}')
      .times(2) # Initial + 1 retry
    
    # Set up orchestrator with OpenAI client
    openai_client = LLM::Client::OpenAI.new(api_key: "test-key")
    orchestrator = Interview::Orchestrator.new(@conversation, llm_client: openai_client)
    
    user_message = @conversation.messages.create!(role: :user, content: "I have problems")
    
    response = orchestrator.process_user_message(user_message)
    
    # Should have switched to fallback mode and asked first fallback question
    @conversation.reload
    assert_equal "fallback", @conversation.state
    assert_equal true, @conversation.meta["fallback_mode"]
    
    expected_question = "最近直面した課題や不便と、その具体的な場面を教えてください。"
    assert_equal expected_question, response
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
    # Stub successful OpenAI response
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(
        status: 200,
        body: {
          choices: [{ message: { content: "OpenAI response" } }]
        }.to_json
      )
    
    # Temporarily set environment to production
    original_env = Rails.env
    Rails.env = "production"
    
    begin
      ENV['OPENAI_API_KEY'] = 'test-key'
      orchestrator = Interview::Orchestrator.new(@conversation)
      user_message = @conversation.messages.create!(role: :user, content: "Hello")
      
      response = orchestrator.process_user_message(user_message)
      
      assert_equal "OpenAI response", response
      assert_equal "enumerate", @conversation.reload.state
    ensure
      Rails.env = original_env
      ENV.delete('OPENAI_API_KEY')
    end
  end

  test "handles network timeout and retries" do
    # First request times out, second succeeds
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_timeout
      .then
      .to_return(
        status: 200,
        body: {
          choices: [{ message: { content: "Success after timeout" } }]
        }.to_json
      )
    
    ENV['OPENAI_API_KEY'] = 'test-key'
    openai_client = LLM::Client::OpenAI.new(api_key: "test-key")
    orchestrator = Interview::Orchestrator.new(@conversation, llm_client: openai_client)
    
    user_message = @conversation.messages.create!(role: :user, content: "Hello")
    
    response = orchestrator.process_user_message(user_message)
    
    assert_equal "Success after timeout", response
    assert_equal "enumerate", @conversation.reload.state
  ensure
    ENV.delete('OPENAI_API_KEY')
  end
end