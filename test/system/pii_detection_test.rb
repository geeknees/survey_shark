require "application_system_test_case"

class PiiDetectionTest < ApplicationSystemTestCase
  def setup
    @project = projects(:one)
    @participant = participants(:one)
    @conversation = conversations(:one)
  end

  test "PII is detected and masked in real time" do
    visit conversation_path(@conversation)

    # Post a message with PII
    fill_in "content", with: "私の名前は田中太郎です。電話番号は03-1234-5678です。"
    click_button "送信"

    # Should see the original message initially
    assert_text "私の名前は田中太郎です。電話番号は03-1234-5678です。"

    # Process the PII detection job
    perform_enqueued_jobs

    # Should see the masked version
    assert_text "[氏名]"
    assert_text "[電話番号]"
    assert_no_text "田中太郎"
    assert_no_text "03-1234-5678"

    # Should see PII warning banner
    assert_text "個人情報が検出されました"
    assert_text "プライバシー保護のため"

    # Should see PII indicator on the message
    assert_text "🔒 個人情報をマスクしました"
  end

  test "messages without PII are not modified" do
    visit conversation_path(@conversation)

    # Post a message without PII
    safe_message = "今日は良い天気ですね。仕事が大変です。"
    fill_in "content", with: safe_message
    click_button "送信"

    # Should see the original message
    assert_text safe_message

    # Process the PII detection job
    perform_enqueued_jobs

    # Message should remain unchanged
    assert_text safe_message

    # Should not see PII warning banner
    assert_no_text "個人情報が検出されました"

    # Should not see PII indicator
    assert_no_text "🔒 個人情報をマスクしました"
  end

  test "skip messages are not processed for PII" do
    visit conversation_path(@conversation)

    # Click skip button
    click_button "スキップ"

    # Should see skip message
    assert_text "[スキップ]"

    # Process any jobs
    perform_enqueued_jobs

    # Skip message should remain unchanged
    assert_text "[スキップ]"

    # Should not see PII warning
    assert_no_text "個人情報が検出されました"
  end

  test "multiple PII types are detected and masked" do
    visit conversation_path(@conversation)

    # Post a message with multiple PII types
    complex_message = "私は田中太郎です。電話番号は03-1234-5678で、test@example.comにメールしてください。東京都渋谷区に住んでいます。"
    fill_in "content", with: complex_message
    click_button "送信"

    # Process the PII detection job
    perform_enqueued_jobs

    # Should see all PII types masked
    assert_text "[氏名]"
    assert_text "[電話番号]"
    assert_text "[メールアドレス]"
    assert_text "[住所]"

    # Should not see original PII
    assert_no_text "田中太郎"
    assert_no_text "03-1234-5678"
    assert_no_text "test@example.com"
    assert_no_text "東京都渋谷区"

    # Should see warning banner
    assert_text "個人情報が検出されました"
  end

  test "PII detection works with company and school names" do
    visit conversation_path(@conversation)

    # Post a message with company and school names
    message = "株式会社テストで働いています。東京大学を卒業しました。"
    fill_in "content", with: message
    click_button "送信"

    # Process the PII detection job
    perform_enqueued_jobs

    # Should see masked versions
    assert_text "[会社名]"
    assert_text "[学校名]"

    # Should not see original names
    assert_no_text "株式会社テスト"
    assert_no_text "東京大学"

    # Should see warning banner
    assert_text "個人情報が検出されました"
  end

  test "conversation continues normally after PII detection" do
    visit conversation_path(@conversation)

    # Post a message with PII
    fill_in "content", with: "私の名前は田中太郎です。"
    click_button "送信"

    # Process jobs
    perform_enqueued_jobs

    # Should see masked message
    assert_text "[氏名]"

    # Should be able to continue conversation
    fill_in "content", with: "今日は良い天気ですね。"
    click_button "送信"

    # Should see new message
    assert_text "今日は良い天気ですね。"
  end
end
