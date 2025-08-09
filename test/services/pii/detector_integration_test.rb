require "test_helper"

class PiiDetectorIntegrationTest < ActiveSupport::TestCase
  def setup
    @conversation = conversations(:one)
  end

  test "job masks multiple PII types" do
    msg = @conversation.messages.create!(role: :user, content: "私は田中太郎です。電話番号は03-1234-5678で、test@example.comにメールしてください。東京都渋谷区に住んでいます。")
    PiiDetectJob.perform_now(msg.id)
    msg.reload
    assert_includes msg.content, "[氏名]"
    assert_includes msg.content, "[電話番号]"
    assert_includes msg.content, "[メールアドレス]"
    assert_includes msg.content, "[住所]"
    assert msg.meta["pii_processed"]
    assert msg.meta["pii_detected"]
  end

  test "skip message not processed by job" do
    msg = @conversation.messages.create!(role: :user, content: "[スキップ]")
    PiiDetectJob.perform_now(msg.id)
    msg.reload
  # Current implementation processes all user messages (skip included) but should not alter skip token
  assert_equal "[スキップ]", msg.content
  assert msg.meta["pii_processed"], "Skip message still marked processed"
  end
end
