require "test_helper"

class PII::DetectorTest < ActiveSupport::TestCase
  def setup
    @detector = PII::Detector.new(llm_client: PII::FakeLLMClient.new)
  end

  test "detects PII in text with names" do
    text = "私の名前は田中太郎です。"
    result = @detector.analyze(text)

    assert result.pii_detected?
    assert_includes result.masked_content, "[氏名]"
    assert_includes result.detected_items, "氏名"
    refute_includes result.masked_content, "田中太郎"
  end

  test "detects PII in text with phone numbers" do
    text = "電話番号は03-1234-5678です。"
    result = @detector.analyze(text)

    assert result.pii_detected?
    assert_includes result.masked_content, "[電話番号]"
    assert_includes result.detected_items, "電話番号"
    refute_includes result.masked_content, "03-1234-5678"
  end

  test "detects PII in text with email addresses" do
    text = "メールアドレスはtest@example.comです。"
    result = @detector.analyze(text)

    assert result.pii_detected?
    assert_includes result.masked_content, "[メールアドレス]"
    assert_includes result.detected_items, "メールアドレス"
    refute_includes result.masked_content, "test@example.com"
  end

  test "detects PII in text with addresses" do
    text = "住所は東京都渋谷区です。"
    result = @detector.analyze(text)

    assert result.pii_detected?
    assert_includes result.masked_content, "[住所]"
    assert_includes result.detected_items, "住所"
    refute_includes result.masked_content, "東京都渋谷区"
  end

  test "detects PII in text with company names" do
    text = "株式会社テストで働いています。"
    result = @detector.analyze(text)

    assert result.pii_detected?
    assert_includes result.masked_content, "[会社名]"
    assert_includes result.detected_items, "会社名"
    refute_includes result.masked_content, "株式会社テスト"
  end

  test "detects PII in text with school names" do
    text = "東京大学で勉強しています。"
    result = @detector.analyze(text)

    assert result.pii_detected?
    assert_includes result.masked_content, "[学校名]"
    assert_includes result.detected_items, "学校名"
    refute_includes result.masked_content, "東京大学"
  end

  test "does not detect PII in safe text" do
    text = "今日は良い天気ですね。仕事が大変です。"
    result = @detector.analyze(text)

    refute result.pii_detected?
    assert_equal text, result.masked_content
    assert_empty result.detected_items
  end

  test "detects multiple types of PII" do
    text = "私は田中太郎です。電話番号は03-1234-5678で、test@example.comにメールしてください。"
    result = @detector.analyze(text)

    assert result.pii_detected?
    assert_includes result.masked_content, "[氏名]"
    assert_includes result.masked_content, "[電話番号]"
    assert_includes result.masked_content, "[メールアドレス]"
    assert_includes result.detected_items, "氏名"
    assert_includes result.detected_items, "電話番号"
    assert_includes result.detected_items, "メールアドレス"
  end

  test "handles LLM errors gracefully" do
    error_client = Class.new do
      def generate_response(**args)
        raise "LLM Error"
      end
    end

    detector = PII::Detector.new(llm_client: error_client.new)
    result = detector.analyze("田中太郎です")

    # Should not detect PII on error (safe default)
    refute result.pii_detected?
    assert_equal "田中太郎です", result.masked_content
  end

  test "uses fake client in test environment" do
    detector = PII::Detector.new
    assert_instance_of PII::FakeLLMClient, detector.instance_variable_get(:@llm_client)
  end
end
