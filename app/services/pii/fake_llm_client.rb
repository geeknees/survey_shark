module PII
  class FakeLLMClient
    # Fake LLM client for testing PII detection

    def initialize(responses: nil)
      @responses = responses || default_responses
  end

  def generate_response(system_prompt:, behavior_prompt:, conversation_history:, user_message:)
    text = extract_text_from_prompt(user_message)

    # Simple rule-based detection for testing
    if contains_pii?(text)
      pii_response(text)
    else
      no_pii_response
    end
  end

  private

  def extract_text_from_prompt(prompt)
    # Extract the actual text from the detection prompt
    if prompt =~ /以下のテキストから個人情報を検出してマスクしてください：\n\n(.+)/m
      $1.strip
    else
      prompt
    end
  end

  def contains_pii?(text)
    # Simple patterns for testing
    pii_patterns = [
      /田中|佐藤|山田|鈴木|高橋/,  # Common Japanese names
      /\d{2,4}-\d{2,4}-\d{4}/,     # Phone numbers
      /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/, # Email
      /東京都.*区|大阪府.*市|.*県.*市.*町/, # Detailed addresses
      /株式会社|有限会社/,           # Company names
      /大学|高校|中学校|小学校/       # School names
    ]

    pii_patterns.any? { |pattern| text.match?(pattern) }
  end

  def pii_response(text)
    masked_text = mask_pii(text)
    detected_items = detect_items(text)

    <<~RESPONSE
      PII_DETECTED: true
      MASKED_TEXT: #{masked_text}
      DETECTED_ITEMS: #{detected_items.join(', ')}
    RESPONSE
  end

  def no_pii_response
    <<~RESPONSE
      PII_DETECTED: false
      MASKED_TEXT: [元のテキストをそのまま]
      DETECTED_ITEMS: なし
    RESPONSE
  end

  def mask_pii(text)
    masked = text.dup

    # Mask names
    masked.gsub!(/田中|佐藤|山田|鈴木|高橋/, "[氏名]")

    # Mask phone numbers
    masked.gsub!(/\d{2,4}-\d{2,4}-\d{4}/, "[電話番号]")

    # Mask emails
    masked.gsub!(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/, "[メールアドレス]")

    # Mask addresses
    masked.gsub!(/東京都.*区|大阪府.*市|.*県.*市.*町/, "[住所]")

    # Mask companies
    masked.gsub!(/株式会社.*|有限会社.*/, "[会社名]")

    # Mask schools
    masked.gsub!(/.*大学|.*高校|.*中学校|.*小学校/, "[学校名]")

    masked
  end

  def detect_items(text)
    items = []

    items << "氏名" if text.match?(/田中|佐藤|山田|鈴木|高橋/)
    items << "電話番号" if text.match?(/\d{2,4}-\d{2,4}-\d{4}/)
    items << "メールアドレス" if text.match?(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/)
    items << "住所" if text.match?(/東京都.*区|大阪府.*市|.*県.*市.*町/)
    items << "会社名" if text.match?(/株式会社|有限会社/)
    items << "学校名" if text.match?(/大学|高校|中学校|小学校/)

    items
  end

  def default_responses
    [ no_pii_response ]
  end
  end
end
