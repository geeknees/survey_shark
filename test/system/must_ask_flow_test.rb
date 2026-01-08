# ABOUTME: System test for must-ask questions appearing in the chat UI.
# ABOUTME: Confirms must-ask priority even when turn limits are tight.
require "application_system_test_case"

class MustAskFlowTest < ApplicationSystemTestCase
  test "asks must_ask after deepening on the conversation page" do
    conversation = conversations(:one)
    project = conversation.project

    project.update!(
      must_ask: [ "年齢" ],
      limits: project.limits.merge("max_deep" => 1, "max_turns" => 1)
    )
    conversation.update!(state: "deepening", meta: { "deepening_turn_count" => 1 })

    visit conversation_path(conversation)

    fill_in "content", with: "More details"
    perform_enqueued_jobs do
      click_button "送信"
    end

    wait_for_message("次に、「年齢」について教えてください。")
  end
end
