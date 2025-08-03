class Conversation < ApplicationRecord
  belongs_to :project
  belongs_to :participant, optional: true
  has_many :messages, dependent: :destroy
  has_many :insight_cards, dependent: :destroy

  validates :state, inclusion: { in: %w[intro enumerate recommend choose deepening summary_check done fallback] }
end
