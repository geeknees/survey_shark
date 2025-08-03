class InsightsController < ApplicationController
  before_action :set_project

  def index
    # Get top 5 insights by frequency priority
    # Primary sort: freq_conversations (descending)
    # Secondary sort: freq_messages (descending)
    @insights = @project.insight_cards
                        .order(freq_conversations: :desc, freq_messages: :desc)
                        .limit(5)

    @total_conversations = @project.conversations.where.not(finished_at: nil).count
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

  def set_project
    @project = Project.find(params[:project_id])
  end
end
