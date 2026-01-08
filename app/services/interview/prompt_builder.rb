# ABOUTME: Builds system and behavior prompts for the interview LLM.
# ABOUTME: Encodes project constraints, must-ask items, and phase guidance.
module Interview
  class PromptBuilder
    def initialize(project)
      @project = project
    end

    def system_prompt
      tone = @project.tone || "polite_soft"
      limits = @project.limits.is_a?(Hash) ? @project.limits : {}
      max_deep = limits["max_deep"] || limits[:max_deep] || 5

      <<~PROMPT
        あなたは優しく丁寧なインタビュアーです。以下のルールに従って会話を進めてください：

        ## 基本姿勢
        - 敬語（丁寧語）を使用し、#{tone_description(tone)}な口調で話してください
        - 1ターンにつき1つの質問のみ行ってください
        - 相手の回答を否定せず、共感的に受け止めてください
        - 質問は簡潔で分かりやすくしてください

        ## インタビューの流れ
        1. 深掘りフェーズ: 課題や不便について#{max_deep}回程度、多角的に詳しく聞く
           - 具体的な場面や状況
           - 発生頻度や影響の大きさ
           - 過去の対処方法や試したこと
           - 理想の解決策や期待すること
        2. 要約確認フェーズ: 会話内容を要約し、確認を求める

        ## 制約事項
        #{must_ask_constraints}
        #{never_ask_constraints}

        ## 目標
        #{@project.goal}
      PROMPT
    end

    def behavior_prompt_for_state(state, deepening_turn = 0, must_ask_item: nil, must_ask_followup: false)
      case state
      when "intro"
        initial_hint = @project.initial_question.present? ? "参考: #{@project.initial_question}" : ""
        <<~PROMPT
          感じている課題や不便なことを挙げてもらうための質問を1つ作成してください。
          口調は丁寧で共感的にし、質問は簡潔にしてください。
          #{initial_hint}
        PROMPT
      when "deepening"
        <<~PROMPT
          直前のユーザー回答を踏まえ、次の観点で詳しく聞く質問を1つ作成してください。
          観点: #{deepening_prompt(deepening_turn)}
        PROMPT
      when "must_ask"
        followup_hint = must_ask_followup ? "追質問として、曖昧な点を具体化できるように" : "初回質問として"
        <<~PROMPT
          必ず聞く項目: #{must_ask_item}
          直前のユーザー回答を踏まえ、#{followup_hint}この項目についての質問を1つ作成してください。
        PROMPT
      when "summary_check"
        <<~PROMPT
          以下の要約をまとめとして提示し、内容の確認を求める質問を1つ作成してください。
          {summary}
        PROMPT
      else
        "会話を丁寧に締めくくる短い一文を作成してください。"
      end
    end

    private

    def deepening_prompt(turn_count)
      case turn_count
      when 0, 1
        "その課題について、もう少し詳しく教えていただけますか？具体的にはどのような場面でお困りですか？"
      when 2
        "それはどのくらいの頻度で発生しますか？また、どの程度お困りですか？"
      when 3
        "これまでに何か対処しようと試されたことはありますか？あれば、その結果も教えてください。"
      when 4
        "理想的には、その課題がどのように解決されるとよいとお考えですか？"
      else
        "その課題について、他に何か補足しておきたいことはありますか？"
      end
    end

    def tone_description(tone)
      case tone
      when "polite_soft"
        "優しく丁寧"
      when "polite_firm"
        "丁寧かつ端的"
      when "casual_soft"
        "親しみやすく穏やか"
      when "casual_firm"
        "カジュアルだが明快"
      else
        "丁寧"
      end
    end

    def must_ask_constraints
      return "" if @project.must_ask.blank?

      "## 必ず聞くべき項目\n" + @project.must_ask.map { |item| "- #{item}" }.join("\n")
    end

    def never_ask_constraints
      return "" if @project.never_ask.blank?

      "## 聞いてはいけない項目\n" + @project.never_ask.map { |item| "- #{item}" }.join("\n")
    end
  end
end
