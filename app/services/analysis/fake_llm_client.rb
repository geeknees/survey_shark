module Analysis
  class FakeLLMClient
    def initialize(responses: nil)
      @responses = responses || default_responses
      @call_count = 0
    end

  def generate_response(system_prompt:, behavior_prompt:, conversation_history:, user_message:)
    response = @responses[@call_count % @responses.length]
    @call_count += 1

    # Extract text from the analysis prompt to make response more relevant
    # Note: text normalization converts "コンピューター" to "コンピュタ" (removes long vowel mark)
    if user_message.include?("コンピュタ") || user_message.include?("コンピュータ") || user_message.include?("パソコン")
      computer_response
    elsif user_message.include?("仕事") || user_message.include?("作業")
      work_response
    else
      response
    end
  end

  private

  def default_responses
    [
      <<~RESPONSE
        THEME: システムの使いやすさ
        JTBD: 効率的に作業を完了したい
        SUMMARY: ユーザーはシステムの操作性に課題を感じており、より直感的で使いやすいインターフェースを求めている
        SEVERITY: 3
        EVIDENCE: 使い方がわからない|操作が複雑すぎる
      RESPONSE
    ]
  end

  def computer_response
    <<~RESPONSE
      THEME: コンピューターの性能問題
      JTBD: スムーズにコンピューター作業を行いたい
      SUMMARY: コンピューターの動作が遅く、作業効率に影響している
      SEVERITY: 4
      EVIDENCE: コンピューターが遅い|フリーズしてしまう
    RESPONSE
  end

  def work_response
    <<~RESPONSE
      THEME: 業務効率の改善
      JTBD: 効率的に業務を遂行したい
      SUMMARY: 現在の業務プロセスに非効率な部分があり、改善が必要
      SEVERITY: 3
      EVIDENCE: 作業に時間がかかる|手順が複雑
    RESPONSE
  end
  end
end
