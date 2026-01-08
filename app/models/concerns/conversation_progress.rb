# ABOUTME: Provides conversation progress metrics and human-readable status.
# ABOUTME: Exposes remaining turns, progress percent, and must-ask awareness.
module ConversationProgress
  extend ActiveSupport::Concern

  # Get number of user messages (excluding system messages)
  def user_message_count
    messages.where(role: 0).count
  end

  # Get number of assistant messages
  def assistant_message_count
    messages.where(role: 1).count
  end

  # Get total number of messages
  def total_message_count
    messages.count
  end

  # Get maximum allowed turns from project limits
  def max_turns
    (project.limits.dig("max_turns") || 12).to_i
  end

  # Get remaining turns available
  def remaining_turns
    max_turns - user_message_count
  end

  # Check if should finish based on turns
  def should_finish?
    at_turn_limit? || in_state?("done")
  end

  # Calculate conversation progress percentage (0-100)
  def progress_percentage
    return 100 if finished?
    return 0 if max_turns.zero?

    ((user_message_count.to_f / max_turns) * 100).round
  end

  # Get human-readable progress status
  def progress_status
    return "完了" if finished?
    return "フォールバック" if fallback_mode?

    case state
    when "intro"
      "開始"
    when "enumerate"
      "課題の列挙"
    when "recommend"
      "推奨"
    when "choose"
      "選択"
    when "deepening"
      "深掘り"
    when "must_ask"
      "必須質問"
    when "summary_check"
      "確認"
    else
      "不明"
    end
  end

  def must_ask_pending?
    Interview::MustAskManager.new(project, meta).pending?
  end
end
