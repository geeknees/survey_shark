require "test_helper"

class PII::FakeLLMClientTest < ActiveSupport::TestCase
  def setup
    @client = PII::FakeLLMClient.new
  end

  test "detects PII in text with names" do
    prompt = "以下のテキストから個人情報を検出してマスクしてください：\n\n私の名前は田中太郎です。"
    response = @client.generate_response(
      system_prompt: "",
      behavior_prompt: "",
      conversation_history: [],
      user_message: prompt
    )

    assert_includes response, "PII_DETECTED: true"
    assert_includes response, "MASKED_TEXT:"
    assert_includes response, "[氏名]"
    assert_includes response, "DETECTED_ITEMS: 氏名"
  end

  test "detects PII in text with phone numbers" do
    prompt = "以下のテキストから個人情報を検出してマスクしてください：\n\n電話番号は03-1234-5678です。"
    response = @client.generate_response(
      system_prompt: "",
      behavior_prompt: "",
      conversation_history: [],
      user_message: prompt
    )

    assert_includes response, "PII_DETECTED: true"
    assert_includes response, "[電話番号]"
    assert_includes response, "DETECTED_ITEMS: 電話番号"
  end

  test "does not detect PII in safe text" do
    prompt = "以下のテキストから個人情報を検出してマスクしてください：\n\n今日は良い天気ですね。"
    response = @client.generate_response(
      system_prompt: "",
      behavior_prompt: "",
      conversation_history: [],
      user_message: prompt
    )

    assert_includes response, "PII_DETECTED: false"
    assert_includes response, "DETECTED_ITEMS: なし"
  end

  test "masks multiple types of PII" do
    prompt = "以下のテキストから個人情報を検出してマスクしてください：\n\n私は田中太郎です。電話番号は03-1234-5678です。"
    response = @client.generate_response(
      system_prompt: "",
      behavior_prompt: "",
      conversation_history: [],
      user_message: prompt
    )

    assert_includes response, "PII_DETECTED: true"
    assert_includes response, "[氏名]"
    assert_includes response, "[電話番号]"
    assert_includes response, "氏名, 電話番号"
  end

  test "handles email addresses" do
    prompt = "以下のテキストから個人情報を検出してマスクしてください：\n\ntest@example.comにメールしてください。"
    response = @client.generate_response(
      system_prompt: "",
      behavior_prompt: "",
      conversation_history: [],
      user_message: prompt
    )

    assert_includes response, "PII_DETECTED: true"
    assert_includes response, "[メールアドレス]"
    assert_includes response, "メールアドレス"
  end

  test "handles company names" do
    prompt = "以下のテキストから個人情報を検出してマスクしてください：\n\n株式会社テストで働いています。"
    response = @client.generate_response(
      system_prompt: "",
      behavior_prompt: "",
      conversation_history: [],
      user_message: prompt
    )

    assert_includes response, "PII_DETECTED: true"
    assert_includes response, "[会社名]"
    assert_includes response, "会社名"
  end

  test "handles school names" do
    prompt = "以下のテキストから個人情報を検出してマスクしてください：\n\n東京大学で勉強しています。"
    response = @client.generate_response(
      system_prompt: "",
      behavior_prompt: "",
      conversation_history: [],
      user_message: prompt
    )

    assert_includes response, "PII_DETECTED: true"
    assert_includes response, "[学校名]"
    assert_includes response, "学校名"
  end
end
