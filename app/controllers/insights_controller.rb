class InsightsController < ApplicationController
  before_action :set_project

  def index
    @insights = top_insights

    @total_conversations = @project.conversations.where.not(finished_at: nil).count
  end

  def export
    insights = top_insights
    filename_base = "project-#{@project.id}-insights-#{Date.current}"

    case params[:format_type]
    when "csv"
      send_data insights_as_csv(insights),
                filename: "#{filename_base}.csv",
                type: "text/csv; charset=utf-8"
    when "markdown"
      send_data insights_as_markdown(insights),
                filename: "#{filename_base}.md",
                type: "text/markdown; charset=utf-8"
    else
      redirect_to project_insights_path(@project), alert: "Unsupported export format."
    end
  end

  def show
    @insight = @project.insight_cards.find(params[:id])
    @related_conversations = @project.conversations
                                    .joins(:messages)
                                    .where(messages: { content: @insight.evidence })
                                    .distinct
                                    .limit(10)
  end

  private

  def top_insights
    # Get top 5 insights by frequency priority
    # Primary sort: freq_conversations (descending)
    # Secondary sort: freq_messages (descending)
    @project.insight_cards
            .order(freq_conversations: :desc, freq_messages: :desc)
            .limit(5)
  end

  def insights_as_csv(insights)
    rows = []
    rows << %w[rank theme jtbds severity freq_conversations freq_messages confidence_label evidence]

    insights.each_with_index do |insight, index|
      rows << [
        index + 1,
        insight.theme,
        insight.jtbds,
        insight.severity,
        insight.freq_conversations,
        insight.freq_messages,
        insight.confidence_label,
        insight.evidence.join(" | ")
      ]
    end

    rows.map { |row| row.map { |value| csv_escape(value) }.join(",") }.join("\n") + "\n"
  end

  def insights_as_markdown(insights)
    lines = []
    lines << "# インサイトレポート"
    lines << ""
    lines << "プロジェクト: #{@project.name}"
    lines << "出力日: #{Date.current}"
    lines << ""

    insights.each_with_index do |insight, index|
      lines << "## #{index + 1}. #{insight.theme}"
      lines << "- JTBD: #{insight.jtbds}"
      lines << "- 深刻度: #{insight.severity}/5"
      lines << "- 発生頻度: 会話 #{insight.freq_conversations} / 発言 #{insight.freq_messages}"
      lines << "- 確信度: #{insight.confidence_label}"
      if insight.evidence.any?
        lines << "- 代表引用:"
        insight.evidence.first(2).each do |quote|
          lines << "  - #{quote}"
        end
      end
      lines << ""
    end

    lines.join("\n")
  end

  def set_project
    @project = Project.find(params[:project_id])
  end

  def csv_escape(value)
    string_value = value.to_s
    escaped = string_value.gsub("\"", "\"\"")
    "\"#{escaped}\""
  end
end
