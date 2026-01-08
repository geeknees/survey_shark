# ABOUTME: System test for must-ask questions appearing in the chat UI.
# ABOUTME: Confirms must-ask priority even when turn limits are tight.
require "application_system_test_case"

class MustAskFlowTest < ApplicationSystemTestCase
  test "asks must_ask after deepening on the conversation page" do
    original_key = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = ""
    conversation = conversations(:one)
    project = conversation.project

    project.update!(
      must_ask: [ "年齢" ],
      limits: project.limits.merge("max_deep" => 1, "max_turns" => 1)
    )
    conversation.update!(state: "deepening", meta: { "deepening_turn_count" => 1 })

    visit conversation_path(conversation)

    fill_in "content", with: "More details"
    click_button "送信"

    start = Time.now
    loop do
      perform_enqueued_jobs
      break if Message.where("content LIKE ?", "%年齢%").exists?
      break if Time.now - start > 10
      sleep 0.1
    end
    assert Message.where("content LIKE ?", "%年齢%").exists?
  ensure
    ENV["OPENAI_API_KEY"] = original_key
  end
end
