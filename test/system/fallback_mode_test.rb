require "application_system_test_case"
require "webmock/minitest"

class FallbackModeTest < ApplicationSystemTestCase
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

      # Post a message that will trigger OpenAI error
      fill_in "content", with: "I have computer problems"
      click_button "送信"

      # Should see the user message
      assert_text "I have computer problems"

      # Should see first fallback question
      assert_text "最近直面した課題や不便と、その具体的な場面を教えてください。"

      # Continue with fallback flow
      fill_in "content", with: "My computer is very slow"
      click_button "送信"

      # Should see second fallback question
      assert_text "先ほど挙げられた中から、最も重要だと思う1件を選び、その理由を一言で教えてください。"

      # Continue to third question
      fill_in "content", with: "The slowness is most important because it affects my work"
      click_button "送信"

      # Should see third fallback question
      assert_text "今思っていることを書いてください。"

      # Final response
      fill_in "content", with: "I think we need better computers"
      click_button "送信"

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

    # Question 1
    fill_in "content", with: "Response to question 1"
    click_button "送信"
    assert_text "先ほど挙げられた中から、最も重要だと思う1件を選び"

    # Question 2
    fill_in "content", with: "Response to question 2"
    click_button "送信"
    assert_text "今思っていることを書いてください。"

    # Question 3 (final)
    fill_in "content", with: "Response to question 3"
    click_button "送信"
    assert_text "ご協力いただき、ありがとうございました。"

    # No more questions should be asked
    assert_no_selector "textarea[name='content']", wait: 1
  end
end
