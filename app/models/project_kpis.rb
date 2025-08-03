class ProjectKpis
  attr_reader :project

  def initialize(project)
    @project = project
  end

  def total_responses
    project.conversations.where.not(finished_at: nil).count
  end

  def max_responses
    project.max_responses
  end

  def remaining_slots
    [max_responses - total_responses, 0].max
  end

  def strong_pain_rate
    return 0.0 if total_responses == 0
    
    strong_pain_conversations = project.conversations
                                      .joins(:insight_cards)
                                      .where(insight_cards: { severity: 4.. })
                                      .distinct
                                      .count
    
    (strong_pain_conversations.to_f / total_responses * 100).round(1)
  end

  def average_turn_count
    finished_conversations = project.conversations.where.not(finished_at: nil)
    return 0.0 if finished_conversations.empty?
    
    total_turns = finished_conversations.joins(:messages)
                                       .where(messages: { role: 0 })  # user messages only
                                       .count
    
    (total_turns.to_f / finished_conversations.count).round(1)
  end

  def completion_rate
    return 0.0 if project.responses_count == 0
    
    (total_responses.to_f / project.responses_count * 100).round(1)
  end

  def is_at_limit?
    total_responses >= max_responses
  end

  def should_auto_close?
    project.active? && is_at_limit?
  end
end