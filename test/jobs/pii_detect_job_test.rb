require "test_helper"

class PiiDetectJobTest < ActiveJob::TestCase
  def setup
    @conversation = conversations(:one)
    @message_with_pii = @conversation.messages.create!(
      role: :user,
      content: "私の名前は田中太郎です。電話番号は03-1234-5678です。"
    )
    @message_without_pii = @conversation.messages.create!(
      role: :user,
      content: "今日は良い天気ですね。"
    )
  end

  test "detects and masks PII in user message" do
    PiiDetectJob.perform_now(@message_with_pii.id)
    
    @message_with_pii.reload
    
    # Content should be masked
    assert_includes @message_with_pii.content, "[氏名]"
    assert_includes @message_with_pii.content, "[電話番号]"
    refute_includes @message_with_pii.content, "田中太郎"
    refute_includes @message_with_pii.content, "03-1234-5678"
    
    # Meta should be updated
    assert_equal true, @message_with_pii.meta["pii_processed"]
    assert_equal true, @message_with_pii.meta["pii_detected"]
    assert @message_with_pii.meta["original_content_hash"].present?
  end

  test "processes message without PII correctly" do
    PiiDetectJob.perform_now(@message_without_pii.id)
    
    @message_without_pii.reload
    
    # Content should remain unchanged
    assert_equal "今日は良い天気ですね。", @message_without_pii.content
    
    # Meta should be updated
    assert_equal true, @message_without_pii.meta["pii_processed"]
    assert_equal false, @message_without_pii.meta["pii_detected"]
  end

  test "skips assistant messages" do
    assistant_message = @conversation.messages.create!(
      role: :assistant,
      content: "田中さん、こんにちは。"
    )
    
    PiiDetectJob.perform_now(assistant_message.id)
    
    assistant_message.reload
    
    # Should not be processed
    assert_nil assistant_message.meta&.dig("pii_processed")
    assert_equal "田中さん、こんにちは。", assistant_message.content
  end

  test "skips already processed messages" do
    @message_with_pii.update!(meta: { pii_processed: true })
    original_content = @message_with_pii.content
    
    PiiDetectJob.perform_now(@message_with_pii.id)
    
    @message_with_pii.reload
    
    # Content should remain unchanged
    assert_equal original_content, @message_with_pii.content
  end

  test "handles LLM errors gracefully" do
    # Mock LLM client to raise error
    detector = PII::Detector.new(llm_client: ErrorLLMClient.new)
    PII::Detector.stub(:new, detector) do
      assert_nothing_raised do
        PiiDetectJob.perform_now(@message_with_pii.id)
      end
    end
    
    @message_with_pii.reload
    
    # Should mark as processed but not detected due to error
    assert_equal true, @message_with_pii.meta["pii_processed"]
    assert_equal false, @message_with_pii.meta["pii_detected"]
  end

  test "handles non-existent message gracefully" do
    assert_raises(ActiveRecord::RecordNotFound) do
      PiiDetectJob.perform_now(999999)
    end
  end

  private

  class ErrorLLMClient
    def generate_response(**args)
      raise "LLM Error"
    end
  end
end