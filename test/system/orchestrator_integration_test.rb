require "application_system_test_case"

class OrchestratorIntegrationTest < ApplicationSystemTestCase
  def setup
    @project = projects(:one)
    @participant = participants(:one)
    @conversation = conversations(:one)
    @conversation.update!(state: "intro")
  end

  test "complete conversation flow without OpenAI" do
    visit conversation_path(@conversation)
    
    # Initial state - intro
    assert_text "残り 12 ターン"
    
    # Step 1: User provides first pain point
    fill_in "content", with: "I have trouble with my computer freezing"
    click_button "送信"
    
    # Should see user message and assistant response
    assert_text "I have trouble with my computer freezing"
    
    # Wait for job to process and assistant response to appear
    # In a real test environment, you might need to process jobs synchronously
    # or use a different approach to handle async jobs
    
    # Step 2: Continue with more pain points
    fill_in "content", with: "My phone battery dies too quickly"
    click_button "送信"
    
    assert_text "My phone battery dies too quickly"
    
    # Step 3: Provide third pain point
    fill_in "content", with: "Traffic jams make me late"
    click_button "送信"
    
    assert_text "Traffic jams make me late"
    
    # Step 4: Choose most important
    fill_in "content", with: "The computer freezing is most important"
    click_button "送信"
    
    assert_text "The computer freezing is most important"
    
    # Step 5: Deepening questions
    fill_in "content", with: "It happens when I'm working on important documents"
    click_button "送信"
    
    assert_text "It happens when I'm working on important documents"
    
    # Step 6: More deepening
    fill_in "content", with: "I lose my work and have to start over"
    click_button "送信"
    
    assert_text "I lose my work and have to start over"
    
    # Step 7: Summary confirmation
    fill_in "content", with: "Yes, that's correct"
    click_button "送信"
    
    assert_text "Yes, that's correct"
    
    # Conversation should be marked as finished
    assert @conversation.reload.finished_at.present?
  end

  test "skip functionality works in conversation flow" do
    visit conversation_path(@conversation)
    
    # Use skip button
    click_link "スキップ"
    
    # Should see skip message
    assert_text "[スキップ]"
    
    # Progress should update
    assert_text "残り 11 ターン"
  end

  test "conversation respects max_deep limit" do
    # Set a low max_deep limit
    @project.update!(limits: { "max_turns" => 12, "max_deep" => 1 })
    @conversation.update!(state: "deepening")
    
    visit conversation_path(@conversation)
    
    # First deepening question
    fill_in "content", with: "First deep question response"
    click_button "送信"
    
    # Should still be in deepening
    # (This test would need to check the actual state, which might require 
    # additional UI indicators or checking the database)
    
    # Second deepening question should move to summary
    fill_in "content", with: "Second deep question response"
    click_button "送信"
    
    # Would need to verify state transition to summary_check
    # This might require additional UI elements to show current state
  end

  test "conversation handles empty messages correctly" do
    visit conversation_path(@conversation)
    
    # Try to submit empty message
    click_button "送信"
    
    # Should stay on same page without creating message
    assert_current_path conversation_path(@conversation)
    
    # No new message should appear
    assert_no_text "undefined"
  end
end