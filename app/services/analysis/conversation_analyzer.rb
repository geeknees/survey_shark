class Analysis::ConversationAnalyzer
  def initialize(conversation, llm_client: nil)
    @conversation = conversation
    @llm_client = llm_client || default_llm_client
    @text_processor = Analysis::TextProcessor.new
    @keyword_extractor = Analysis::KeywordExtractor.new
  end

  def analyze
    # Extract user messages (excluding skip messages)
    user_messages = @conversation.messages
                                 .where(role: 0)
                                 .where.not(content: "[スキップ]")
                                 .pluck(:content)

    return [] if user_messages.empty?

    # Combine all user text
    combined_text = user_messages.join(" ")

    # Step 1: Normalize text
    normalized_text = @text_processor.normalize(combined_text)

    # Step 2: Tokenize (TinySegmenter)
    tokens = @text_processor.tokenize(normalized_text)

    # Step 3: Extract keywords (RAKE)
    keywords = @keyword_extractor.extract_keywords(tokens)

    # Step 4: LLM analysis for themes and summary
    llm_analysis = analyze_with_llm(normalized_text, keywords)

    # Step 5: Build insights
    build_insights(llm_analysis, user_messages)
  end

  private

  def analyze_with_llm(text, keywords)
    prompt = build_analysis_prompt(text, keywords)

    begin
      response = @llm_client.generate_response(
        system_prompt: system_prompt,
        behavior_prompt: "",
        conversation_history: [],
        user_message: prompt
      )

      parse_llm_analysis(response)
    rescue => e
      Rails.logger.error "LLM analysis failed: #{e.message}"
      # Return fallback analysis
      fallback_analysis(text, keywords)
    end
  end

  def system_prompt
    <<~PROMPT
      あなたは顧客インサイト分析の専門家です。ユーザーの発言から課題やペインポイントを分析し、テーマを抽出してください。

      分析の観点：
      - Jobs to be Done (JTBD): ユーザーが達成しようとしていること
      - ペインポイント: 困っていること、不便に感じていること
      - 感情: フラストレーション、不安、期待など
      - 深刻度: 1(軽微) ～ 5(深刻)

      回答形式：
      THEME: [テーマ名]
      JTBD: [ユーザーが達成したいこと]
      SUMMARY: [要約]
      SEVERITY: [1-5の数値]
      EVIDENCE: [具体的な発言の引用1]|[具体的な発言の引用2]

      複数のテーマがある場合は、上記形式を繰り返してください。
    PROMPT
  end

  def build_analysis_prompt(text, keywords)
    <<~PROMPT
      以下のユーザー発言を分析してください：

      【ユーザー発言】
      #{text}

      【抽出されたキーワード】
      #{keywords.join(', ')}

      上記の発言から、ユーザーの課題やペインポイントのテーマを抽出し、分析してください。
    PROMPT
  end

  def parse_llm_analysis(response)
    themes = []

    # Split response into theme blocks
    theme_blocks = response.split(/(?=THEME:)/).reject(&:empty?)

    theme_blocks.each do |block|
      theme_data = {}

      theme_data[:theme] = extract_field(block, "THEME")
      theme_data[:jtbd] = extract_field(block, "JTBD")
      theme_data[:summary] = extract_field(block, "SUMMARY")
      theme_data[:severity] = extract_field(block, "SEVERITY").to_i

      evidence_text = extract_field(block, "EVIDENCE")
      theme_data[:evidence] = evidence_text.split("|").map(&:strip).reject(&:empty?)

      themes << theme_data if theme_data[:theme].present?
    end

    themes
  end

  def extract_field(text, field_name)
    if text =~ /#{field_name}:\s*(.+?)(?:\n|$)/m
      $1.strip
    else
      ""
    end
  end

  def fallback_analysis(text, keywords)
    # Simple fallback when LLM fails
    [ {
      theme: "ユーザーの課題",
      jtbd: "問題を解決したい",
      summary: text.truncate(100),
      severity: estimate_severity_heuristic(text),
      evidence: [ text.truncate(50) ]
    } ]
  end

  def estimate_severity_heuristic(text)
    # Simple heuristic based on negative words
    negative_words = %w[困る 大変 問題 エラー 失敗 遅い 重い 使えない だめ ひどい]
    strong_negative_words = %w[最悪 ひどすぎる 使い物にならない 全然だめ]

    if strong_negative_words.any? { |word| text.include?(word) }
      5
    elsif negative_words.count { |word| text.include?(word) } >= 2
      4
    elsif negative_words.any? { |word| text.include?(word) }
      3
    else
      2
    end
  end

  def build_insights(llm_themes, user_messages)
    llm_themes.map do |theme_data|
      Analysis::Insight.new(
        theme: theme_data[:theme],
        jtbd: theme_data[:jtbd],
        summary: theme_data[:summary],
        severity: theme_data[:severity],
        message_frequency: user_messages.length,
        evidence: theme_data[:evidence].take(2)
      )
    end
  end

  def default_llm_client
    if Rails.env.test?
      Analysis::FakeLLMClient.new
    else
      LLM::Client::OpenAI.new
    end
  end
end
