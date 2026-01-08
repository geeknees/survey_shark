# ABOUTME: Stores interview conversation state, messages, and progress tracking.
# ABOUTME: Validates state transitions and associates project/participant data.
class Conversation < ApplicationRecord
  include ConversationStateMachine
  include ConversationProgress

  belongs_to :project
  belongs_to :participant, optional: true
  has_many :messages, dependent: :destroy
  has_many :insight_cards, dependent: :destroy

  validates :state, inclusion: { in: %w[intro enumerate recommend choose deepening must_ask summary_check done fallback] }
end
