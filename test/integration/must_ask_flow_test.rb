# ABOUTME: Integration test for must-ask sequencing through the controller/job flow.
# ABOUTME: Ensures must-ask questions are enqueued and delivered after deepening.
require "test_helper"

class MustAskFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "delivers must_ask question after deepening via job" do
    original_key = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = ""
    conversation = conversations(:one)
    project = conversation.project

    project.update!(
      must_ask: [ "年齢" ],
      limits: project.limits.merge("max_deep" => 1, "max_turns" => 1)
    )
    conversation.update!(state: "deepening", meta: { "deepening_turn_count" => 1 })

    perform_enqueued_jobs do
      post create_message_conversation_path(conversation), params: { content: "More details" }
    end

    assistant_message = conversation.messages.assistant.last
    assert_equal "must_ask", conversation.reload.state
    assert_includes assistant_message.content, "年齢"
  ensure
    ENV["OPENAI_API_KEY"] = original_key
  end

  test "allows final summary response even when at turn limit" do
    original_key = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = ""
    conversation = conversations(:one)
    project = conversation.project

    project.update!(limits: project.limits.merge("max_turns" => 0))
    conversation.update!(state: "summary_check")

    perform_enqueued_jobs do
      post create_message_conversation_path(conversation), params: { content: "はい、合っています" }
    end

    assert_equal "done", conversation.reload.state
    assert conversation.finished_at.present?
  ensure
    ENV["OPENAI_API_KEY"] = original_key
  end
end
