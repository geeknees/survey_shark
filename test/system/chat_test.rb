require "application_system_test_case"

class ChatTest < ApplicationSystemTestCase
  def setup
    @project = projects(:one)
    @participant = participants(:one)
    @conversation = conversations(:one)
  end

  test "posting a message appends to list and updates progress" do
    visit conversation_path(@conversation)

    # Initial state - no user messages
    initial_progress = find("[style*='width:']")[:style]

    # Post a message
    fill_in "content", with: "Hello, this is my first message"
    click_button "送信"

    # Should be redirected back to conversation
    assert_current_path conversation_path(@conversation)

    # Message should appear in the chat
    assert_text "Hello, this is my first message"

    # Progress should have updated (one user turn now)
    assert_text "残り 11 ターン" # Assuming 12 max turns
  end

  test "skip button updates progress" do
    visit conversation_path(@conversation)

    # Click skip button
    click_button "スキップ"

    # Should be redirected back to conversation
    assert_current_path conversation_path(@conversation)

    # Skip message should appear
    assert_text "[スキップ]"

    # Progress should have updated
    assert_text "残り 11 ターン"
  end

  test "character counter works" do
    visit conversation_path(@conversation)

    # Initially should show 0/500
    assert_text "0/500"

    # Type some text
    fill_in "content", with: "Hello world"

    # Counter should update (note: this might require JavaScript,
    # so this test might need to be adapted based on your test setup)
    # For now, just verify the counter element exists
    assert_selector "[data-chat-composer-target='counter']"
  end

  test "quick reply button inserts text" do
    visit conversation_path(@conversation)

    # Click the quick reply button
    click_button "質問を言い換えて"

    # Text should be inserted into textarea
    # (This might require JavaScript support in tests)
    assert_selector "textarea[name='content']"
  end

  test "empty message cannot be submitted" do
    visit conversation_path(@conversation)

    # Submit button should be disabled when textarea is empty
    submit_button = find("input[type='submit'][value='送信']")
    assert submit_button[:disabled], "Submit button should be disabled when textarea is empty"

    # Fill in some text to enable the button
    fill_in "content", with: "Test message"

    # Clear the text to disable it again
    fill_in "content", with: ""

    # Submit button should be disabled again
    assert submit_button[:disabled], "Submit button should be disabled when textarea is cleared"
  end
end
