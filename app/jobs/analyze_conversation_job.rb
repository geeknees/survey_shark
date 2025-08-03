class AnalyzeConversationJob < ApplicationJob
  queue_as :default

  def perform(conversation_id)
    conversation = Conversation.find(conversation_id)
    
    # Only analyze finished conversations
    return unless conversation.finished_at.present?
    
    analyzer = Analysis::ConversationAnalyzer.new(conversation)
    insights = analyzer.analyze
    
    # Create or update insight cards for each theme
    insights.each do |insight|
      create_or_update_insight_card(conversation.project, conversation, insight)
    end
    
    Rails.logger.info "Analyzed conversation #{conversation.id}, created #{insights.length} insights"
  end

  private

  def create_or_update_insight_card(project, conversation, insight)
    # Find existing card with same theme or create new one
    card = project.insight_cards.find_by(theme: insight.theme) ||
           project.insight_cards.build(theme: insight.theme)
    
    # Update or set initial values
    if card.persisted?
      # Merge with existing card
      card.freq_conversations += 1
      card.freq_messages += insight.message_frequency
      card.evidence = merge_evidence(card.evidence, insight.evidence)
      card.severity = [card.severity, insight.severity].max if card.severity
    else
      # New card
      card.conversation = conversation
      card.jtbds = insight.jtbd
      card.severity = insight.severity
      card.freq_conversations = 1
      card.freq_messages = insight.message_frequency
      card.evidence = insight.evidence
    end
    
    # Calculate confidence label
    card.confidence_label = calculate_confidence_label(card)
    
    card.save!
  end

  def merge_evidence(existing_evidence, new_evidence)
    # Combine evidence arrays and keep only top 2 by relevance
    combined = (existing_evidence + new_evidence).uniq
    combined.take(2)
  end

  def calculate_confidence_label(card)
    # Confidence = 0.7 * freq + 0.3 * quotes
    freq_score = [card.freq_conversations / 10.0, 1.0].min  # Normalize to 0-1
    quote_score = [card.evidence.length / 2.0, 1.0].min    # Normalize to 0-1
    
    confidence = 0.7 * freq_score + 0.3 * quote_score
    
    case confidence
    when 0.7..1.0
      "H"  # High
    when 0.4..0.7
      "M"  # Medium
    else
      "L"  # Low
    end
  end
end