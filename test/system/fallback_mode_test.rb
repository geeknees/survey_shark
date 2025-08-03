require "application_system_test_case"

class FallbackModeTest < ApplicationSystemTestCase
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

  test "conversation switches to fallback mode on LLM error" do
    # Stub OpenAI to fail
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(status: 500, body: '{"error": "Internal server error"}')
      .times(2) # Initial + 1 retry

    # Set environment to use OpenAI
    original_env = Rails.env
    Rails.env = "production"
    ENV["OPENAI_API_KEY"] = "test-key"

    begin
      visit conversation_path(@conversation)

      # Post a message that will trigger OpenAI error with jobs
      perform_enqueued_jobs do
        fill_in "content", with: "I have computer problems"
        click_button "送信"
      end

      # Should see the user message
      assert_text "I have computer problems"

      # Verify conversation switched to fallback mode
      @conversation.reload
      assert_equal "fallback", @conversation.state, "Conversation should be in fallback state"
      assert_equal true, @conversation.meta["fallback_mode"], "Conversation should be marked as fallback mode"

      # Should see first fallback question
      assert_text "最近直面した課題や不便と、その具体的な場面を教えてください。"

      # Continue with fallback flow
      perform_enqueued_jobs do
        fill_in "content", with: "My computer is very slow"
        click_button "送信"
      end

      # Should see second fallback question
      assert_text "先ほど挙げられた中から、最も重要だと思う1件を選び、その理由を一言で教えてください。"

      # Continue to third question
      perform_enqueued_jobs do
        fill_in "content", with: "The slowness is most important because it affects my work"
        click_button "送信"
      end

      # Should see third fallback question
      assert_text "今思っていることを書いてください。"

      # Final response
      perform_enqueued_jobs do
        fill_in "content", with: "I think we need better computers"
        click_button "送信"
      end

      # Should see completion message
      assert_text "ご協力いただき、ありがとうございました。貴重なお話をお聞かせいただけました。"

      # Verify conversation is marked as finished
      assert @conversation.reload.finished_at.present?
      assert_equal "done", @conversation.state
    ensure
      Rails.env = original_env
      ENV.delete("OPENAI_API_KEY")
    end
  end

  test "fallback mode completes with exactly 3 questions" do
    # Set conversation to fallback mode manually
    @conversation.update!(state: "fallback", meta: { fallback_mode: true })

    visit conversation_path(@conversation)

    # Verify initial state
    puts "Initial conversation state: #{@conversation.reload.state}"
    puts "Initial conversation meta: #{@conversation.meta}"
    puts "Initial message count: #{@conversation.messages.count}"

    # Question 1
    initial_job_count = ActiveJob::Base.queue_adapter.enqueued_jobs.size
    puts "Initial job count: #{initial_job_count}"

    perform_enqueued_jobs do
      fill_in "content", with: "Response to question 1"
      click_button "送信"
    end

    final_job_count = ActiveJob::Base.queue_adapter.enqueued_jobs.size
    puts "Final job count: #{final_job_count}"

    # Debug: Check what messages were created
    @conversation.reload
    puts "After first response - message count: #{@conversation.messages.count}"
    puts "All messages:"
    @conversation.messages.each_with_index do |msg, i|
      puts "  #{i}: #{msg.role} - #{msg.content}"
    end
    puts "User messages count: #{@conversation.messages.where(role: 0).count}"

    assert_text "先ほど挙げられた中から、最も重要だと思う1件を選び"

    # Question 2
    perform_enqueued_jobs do
      fill_in "content", with: "Response to question 2"
      click_button "送信"
    end
    assert_text "今思っていることを書いてください。"

    # Question 3 (final)
    perform_enqueued_jobs do
      fill_in "content", with: "Response to question 3"
      click_button "送信"
    end
    assert_text "ご協力いただき、ありがとうございました。"

    # Verify conversation is finished
    @conversation.reload
    assert_equal "done", @conversation.state
    assert_not_nil @conversation.finished_at

    # No more questions should be asked
    assert_no_selector "textarea[name='content']", wait: 1
  end
end
