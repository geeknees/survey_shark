module Interview
  class PromptBuilder
    def initialize(project)
      @project = project
    end

    def system_prompt
      tone = @project.tone || "polite_soft"
      max_deep = @project.limits.dig("max_deep") || 5

      <<~PROMPT
        あなたは優しく丁寧なインタビュアーです。以下のルールに従って会話を進めてください：

        ## 基本姿勢
        - 敬語（丁寧語）を使用し、#{tone_description(tone)}な口調で話してください
        - 1ターンにつき1つの質問のみ行ってください
        - 相手の回答を否定せず、共感的に受け止めてください
        - 質問は簡潔で分かりやすくしてください

        ## インタビューの流れ
        1. 列挙フェーズ: 日常の課題や不便を3つまで挙げてもらう
        2. 推奨フェーズ: 挙げられた中から最も重要なものを推奨する
        3. 選択フェーズ: ユーザーに最重要な1つを選んでもらう
        4. 深掘りフェーズ: 選択された課題について#{max_deep}回程度、多角的に詳しく聞く
           - 具体的な場面や状況
           - 発生頻度や影響の大きさ
           - 過去の対処方法や試したこと
           - 理想の解決策や期待すること
        5. 要約確認フェーズ: 会話内容を要約し、確認を求める

        ## 制約事項
        #{must_ask_constraints}
        #{never_ask_constraints}

        ## 目標
        #{@project.goal}
      PROMPT
    end

    def behavior_prompt_for_state(state, deepening_turn = 0)
      question = case state
      when "intro"
        @project.initial_question.present? ?
          @project.initial_question :
          "まず、日常生活で感じている課題や不便なことを3つまで教えてください。どんな小さなことでも構いません。"
      when "enumerate"
        "他にも何か課題や不便に感じていることはありますか？（最大3つまで）"
      when "recommend"
        "お聞かせいただいた中で、特に重要だと思われるのは「{most_important}」のようですが、いかがでしょうか？"
      when "choose"
        "挙げていただいた課題の中から、最も重要だと思うものを1つ選んでいただけますか？"
      when "deepening"
        deepening_prompt(deepening_turn)
      when "summary_check"
        "これまでのお話をまとめさせていただきます。内容に間違いがないか確認していただけますか？\n\n{summary}\n\nこの内容で間違いありませんか？"
      else
        "ありがとうございました。"
      end

      # Return as a directive for the LLM to follow exactly
      "次の質問を、そのままの文言で相手に尋ねてください（一切変更を加えず、そのまま出力してください）：\n\n#{question}"
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
