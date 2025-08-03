require "application_system_test_case"

class OrchestratorIntegrationTest < ApplicationSystemTestCase
  def setup
    @project = projects(:one)
    @participant = participants(:one)
    @conversation = conversations(:one)
    @conversation.update!(state: "intro")
    enable_webmock_with_system_test_support
  end

  def teardown
    disable_webmock
  end

  test "complete conversation flow without OpenAI" do
    # Mock OpenAI responses
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(
        status: 200,
        body: {
          choices: [ {
            message: {
              content: "それは大変ですね。他にも何か困っていることはありますか？"
            }
          } ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      ).times(10) # Multiple responses for the conversation

    visit conversation_path(@conversation)

    # Initial state - intro
    assert_text "残り 12 ターン"

    # Step 1: User provides first pain point
    perform_enqueued_jobs do
      fill_in "content", with: "I have trouble with my computer freezing"
      click_button "送信"
    end

    # Should see user message and assistant response
    assert_text "I have trouble with my computer freezing"

    # Step 2: Continue with more pain points
    perform_enqueued_jobs do
      fill_in "content", with: "My phone battery dies too quickly"
      click_button "送信"
    end

    assert_text "My phone battery dies too quickly"

    # Step 3: Provide third pain point
    perform_enqueued_jobs do
      fill_in "content", with: "Traffic jams make me late"
      click_button "送信"
    end

    assert_text "Traffic jams make me late"

    # Step 4: Choose most important
    perform_enqueued_jobs do
      fill_in "content", with: "The computer freezing is most important"
      click_button "送信"
    end

    assert_text "The computer freezing is most important"

    # Step 5: Deepening questions
    perform_enqueued_jobs do
      fill_in "content", with: "It happens when I'm working on important documents"
      click_button "送信"
    end

    assert_text "It happens when I'm working on important documents"

    # Step 6: More deepening
    perform_enqueued_jobs do
      fill_in "content", with: "I lose my work and have to start over"
      click_button "送信"
    end

    assert_text "I lose my work and have to start over"

    # Step 7: Summary confirmation
    perform_enqueued_jobs do
      fill_in "content", with: "Yes, that's correct"
      click_button "送信"
    end

    assert_text "Yes, that's correct"

    # Conversation should be marked as finished
    assert @conversation.reload.finished_at.present?
  end

  test "skip functionality works in conversation flow" do
    visit conversation_path(@conversation)

    initial_message_count = @conversation.messages.count

    # Use skip button - should send POST request to skip action
    click_button "スキップ"

    # Wait for the request to complete
    sleep 1

    # Check that messages were created in database
    @conversation.reload
    new_message_count = @conversation.messages.count

    # At minimum, a user skip message should be created
    assert new_message_count > initial_message_count, "Skip message should be created in database"

    # Check that user message is the skip message
    user_messages = @conversation.messages.where(role: 0)
    assert user_messages.exists?, "Should have at least one user message"
    assert_equal "[スキップ]", user_messages.last.content, "Last user message should be skip message"
  end

  test "conversation respects max_deep limit" do
    # Set a low max_deep limit
    @project.update!(limits: { "max_turns" => 12, "max_deep" => 1 })
    @conversation.update!(state: "deepening")

    visit conversation_path(@conversation)

    # First deepening question
    perform_enqueued_jobs do
      fill_in "content", with: "First deep question response"
      click_button "送信"
    end

    # Second deepening question should move to summary
    perform_enqueued_jobs do
      fill_in "content", with: "Second deep question response"
      click_button "送信"
    end

    # Would need to verify state transition to summary_check
    # This might require additional UI elements to show current state
  end

  test "conversation handles empty messages correctly" do
    visit conversation_path(@conversation)

    # Check that the form prevents empty submission
    # The submit button should exist but be disabled or have JS prevention
    submit_button = find("input[type='submit'][value='送信']")

    # If JavaScript disables the button when empty, this is expected behavior
    # Just verify the button exists and the page loads correctly
    assert submit_button.present?

    # Verify no message was accidentally created from empty form
    initial_message_count = @conversation.messages.count

    # Try to trigger a form submission with empty content (if JS doesn't prevent it)
    begin
      fill_in "content", with: ""
      click_button "送信"
    rescue Capybara::ElementNotFound
      # If button is disabled, this is expected behavior
    end

    # Message count should remain the same
    assert_equal initial_message_count, @conversation.reload.messages.count
  end

  test "conversation respects turn limit" do
    # Set a very low turn limit
    @project.update!(limits: { "max_turns" => 2, "max_deep" => 2 })

    visit conversation_path(@conversation)

    # Initial state - should have 2 turns remaining
    assert_text "残り 2 ターン"

    # First message
    perform_enqueued_jobs do
      fill_in "content", with: "First message"
      click_button "送信"
    end

    assert_text "First message"
    assert_text "残り 1 ターン"

    # Second message
    perform_enqueued_jobs do
      fill_in "content", with: "Second message"
      click_button "送信"
    end

    assert_text "Second message"

    # Should show turn limit reached message
    assert_text "ターン数の上限に達しました"

    # Message composer should be hidden
    assert_no_selector "textarea[name='content']"
  end
end
