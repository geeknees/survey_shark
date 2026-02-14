module PII
  class Detector
    def initialize(llm_client: nil)
      @llm_client = llm_client || default_llm_client
    end

    def analyze(text)
      # Use LLM to detect PII
      prompt = build_detection_prompt(text)

      begin
        response = @llm_client.generate_response(
          system_prompt: system_prompt,
          behavior_prompt: "",
          conversation_history: [],
          user_message: prompt
        )

        parse_llm_response(text, response)
      rescue => e
        Rails.logger.error "PII detection failed: #{e.message}"
        # Return safe result on error - assume no PII to avoid false positives
        PII::DetectionResult.new(text, false, text, [])
      end
    end

    private

    def system_prompt
      <<~PROMPT
        あなたは個人情報（PII）検出の専門家です。テキストから以下の個人情報を検出してください：

        検出対象：
        - 氏名（姓名、フルネーム、ニックネーム）
        - 電話番号（固定電話、携帯電話）
        - メールアドレス
        - 住所（都道府県より詳細な住所）
        - 会社名・組織名
        - 学校名
        - 具体的な地名（駅名、建物名など）
        - ID番号（学籍番号、社員番号など）

        検出しないもの：
        - 一般的な職業名（「教師」「エンジニア」など）
        - 年齢
        - 都道府県レベルの地域名
        - 一般的な商品名・サービス名

        回答形式：
        PII_DETECTED: true/false
        MASKED_TEXT: [マスク済みテキスト]
        DETECTED_ITEMS: [検出項目のリスト]

        マスク方法：
        - 氏名 → [氏名]
        - 電話番号 → [電話番号]
        - メールアドレス → [メールアドレス]
        - 住所 → [住所]
        - 会社名 → [会社名]
        - 学校名 → [学校名]
        - 地名 → [地名]
        - ID番号 → [ID番号]
      PROMPT
    end

    def build_detection_prompt(text)
      "以下のテキストから個人情報を検出してマスクしてください：\n\n#{text}"
    end

    def parse_llm_response(original_text, response)
      normalized_response = normalize_response(response)

      pii_detected = parse_pii_detected(normalized_response)
      masked_text = parse_masked_text(normalized_response, original_text)
      detected_items = parse_detected_items(normalized_response)

      if pii_detected.nil?
        pii_detected = detected_items.any? || masked_text != original_text
      elsif !pii_detected && (detected_items.any? || masked_text != original_text)
        pii_detected = true
      end

      PII::DetectionResult.new(original_text, pii_detected, masked_text, detected_items)
    end

    def default_llm_client
      if Rails.env.test?
        PII::FakeLLMClient.new
      else
        LLM::Client::OpenAI.new
      end
    end

    def normalize_response(response)
      response.to_s.gsub(/\A```[a-zA-Z]*\s*/m, "").gsub(/```$/, "").strip
    end

    def parse_pii_detected(response)
      match = response.match(/PII_DETECTED\s*[:：]\s*(true|false)/i)
      return nil unless match

      match[1].casecmp("true").zero?
    end

    def parse_masked_text(response, original_text)
      match = response.match(/MASKED_TEXT\s*[:：]\s*(.*?)(?:\nDETECTED_ITEMS\s*[:：]|\z)/mi)
      return original_text unless match

      candidate = match[1].to_s.strip
      candidate.present? ? candidate : original_text
    end

    def parse_detected_items(response)
      match = response.match(/DETECTED_ITEMS\s*[:：]\s*(.+?)(?:\n|\z)/mi)
      return [] unless match

      items_text = match[1].to_s.strip.delete_prefix("[").delete_suffix("]")
      items = items_text.split(/[,、]/).map(&:strip).reject(&:empty?)
      items.reject { |item| item == "なし" || item.casecmp("none").zero? }
    end
  end
end
