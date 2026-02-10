# ABOUTME: Builds dynamic quick-reply suggestions for the conversation composer.
# ABOUTME: Uses conversation state and last user input to keep suggestions contextual.
module ConversationsHelper
  MAX_QUICK_REPLIES = 3
  UNKNOWN_RESPONSE_PATTERN = /わから|分から|思いつかない|特にない/.freeze
  NEGATIVE_RESPONSE_PATTERN = /違|ちが|いや/.freeze
  EXCLUDED_USER_MESSAGES = [ "[スキップ]", "[インタビュー開始]" ].freeze

  def quick_reply_suggestions(conversation)
    return [] unless conversation

    state = conversation.state.to_s
    last_user_content = latest_user_content(conversation)
    suggestions = base_quick_replies_for(state).dup

    if detail_phase?(state) && last_user_content.present? && last_user_content.length <= 20
      suggestions.unshift("もう少し具体的に答えます")
    end

    if detail_phase?(state) && last_user_content.match?(UNKNOWN_RESPONSE_PATTERN)
      suggestions.unshift("思い出せる範囲で答えます")
    end

    if detail_phase?(state) && last_user_content.match?(NEGATIVE_RESPONSE_PATTERN)
      suggestions.unshift("別の理由を話します")
    end

    suggestions.map(&:strip).reject(&:blank?).uniq.first(MAX_QUICK_REPLIES)
  end

  private

  def base_quick_replies_for(state)
    case state
    when "intro"
      [ "質問を言い換えて", "最近困ったことを挙げます", "身近な場面から話します" ]
    when "deepening"
      [ "もう少し具体的に答えます", "頻度や影響も補足します", "別の理由もあります" ]
    when "must_ask"
      [ "具体例で答えます", "まだ分かりません", "別の観点で答えます" ]
    when "summary_check"
      [ "はい、合っています", "少し違います", "この点を修正します" ]
    else
      [ "質問を言い換えて" ]
    end
  end

  def latest_user_content(conversation)
    conversation.messages
                .where(role: Message.roles[:user])
                .where.not(content: EXCLUDED_USER_MESSAGES)
                .order(created_at: :desc)
                .limit(1)
                .pick(:content)
                .to_s
  end

  def detail_phase?(state)
    state == "deepening" || state == "must_ask"
  end
end
