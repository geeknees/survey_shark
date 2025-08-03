require "application_system_test_case"

class FallbackModeTest < ApplicationSystemTestCase
  def setup
    @project = projects(:one)
    @participant = participants(:one)
    @conversation = conversations(:one)
    @conversation.update!(state: "intro")
    enable_webmock_with_system_test_support

    # Ensure conversation has initial assistant message for fallback mode tests
    unless @conversation.messages.where(role: 1).exists?
      @conversation.messages.create!(role: 1, content: "MyText")
    end

    # Set log level to debug for tests
    Rails.logger.level = Logger::DEBUG
  end

  def teardown
    disable_webmock
  end

  test "conversation switches to fallback mode on LLM error" do
    # Set environment variable to simulate error
    ENV["SIMULATE_LLM_ERROR"] = "true"

    begin
      visit conversation_path(@conversation)

      # Post a message that will trigger LLM error
      fill_in "content", with: "I have computer problems"
      click_button "送信"

      # Manually execute the job to trigger the error handling
      @conversation.reload
      user_message = @conversation.messages.where(role: 0).last

      if user_message
        StreamAssistantResponseJob.perform_now(@conversation.id, user_message.id)

        # Should see the user message
        visit current_path
        assert_text "I have computer problems"

        # Verify conversation switched to fallback mode
        @conversation.reload
        assert_equal "fallback", @conversation.state, "Conversation should be in fallback state"
        assert_equal true, @conversation.meta["fallback_mode"], "Conversation should be marked as fallback mode"

        # Should see first fallback question
        assert_text "最近直面した課題や不便と、その具体的な場面を教えてください。"
      else
        fail "User message was not created after form submission"
      end

      # Continue with fallback flow
      fill_in "content", with: "My computer is very slow"
      click_button "送信"

      @conversation.reload
      user_message = @conversation.messages.where(role: 0).last
      StreamAssistantResponseJob.perform_now(@conversation.id, user_message.id)

      visit current_path

      # Should see second fallback question
      assert_text "先ほど挙げられた中から、最も重要だと思う1件を選び、その理由を一言で教えてください。"

      # Continue to third question
      fill_in "content", with: "The slowness is most important because it affects my work"
      click_button "送信"

      @conversation.reload
      user_message = @conversation.messages.where(role: 0).last
      StreamAssistantResponseJob.perform_now(@conversation.id, user_message.id)

      visit current_path

      # Should see third fallback question
      assert_text "今思っていることを書いてください。"

      # Final response
      fill_in "content", with: "I think we need better computers"
      click_button "送信"

      @conversation.reload
      user_message = @conversation.messages.where(role: 0).last
      StreamAssistantResponseJob.perform_now(@conversation.id, user_message.id)

      visit current_path

      # Should see completion message
      assert_text "ご協力いただき、ありがとうございました。貴重なお話をお聞かせいただけました。"

      # Verify conversation is marked as finished
      assert @conversation.reload.finished_at.present?
      assert_equal "done", @conversation.state
    ensure
      ENV.delete("SIMULATE_LLM_ERROR")
    end
  end

  test "fallback mode completes with exactly 3 questions" do
    # Set conversation to fallback mode manually
    @conversation.update!(state: "fallback", meta: { fallback_mode: true })

    visit conversation_path(@conversation)

    # Question 1 - should trigger the first fallback question
    fill_in "content", with: "Response to question 1"
    click_button "送信"

    # Manually execute the job since perform_enqueued_jobs doesn't work reliably in system tests
    @conversation.reload
    user_message = @conversation.messages.where(role: 0).last

    if user_message
      StreamAssistantResponseJob.perform_now(@conversation.id, user_message.id)

      # Refresh to see the new message
      visit current_path
      assert_text "最近直面した課題や不便と、その具体的な場面を教えてください。"
    else
      fail "User message was not created after form submission"
    end

    # Question 2
    fill_in "content", with: "Response to question 2"
    click_button "送信"

    @conversation.reload
    user_message = @conversation.messages.where(role: 0).last
    StreamAssistantResponseJob.perform_now(@conversation.id, user_message.id)

    visit current_path
    assert_text "先ほど挙げられた中から、最も重要だと思う1件を選び"

    # Question 3 (final)
    fill_in "content", with: "Response to question 3"
    click_button "送信"

    @conversation.reload
    user_message = @conversation.messages.where(role: 0).last
    StreamAssistantResponseJob.perform_now(@conversation.id, user_message.id)

    visit current_path
    assert_text "今思っていることを書いてください。"

    # Final response that completes the conversation
    fill_in "content", with: "Response to final question"
    click_button "送信"

    @conversation.reload
    user_message = @conversation.messages.where(role: 0).last
    StreamAssistantResponseJob.perform_now(@conversation.id, user_message.id)

    visit current_path
    assert_text "ご協力いただき、ありがとうございました。"

    # Verify conversation is finished
    @conversation.reload
    assert_equal "done", @conversation.state
    assert_not_nil @conversation.finished_at

    # No more questions should be asked
    assert_no_selector "textarea[name='content']", wait: 1
  end
end
