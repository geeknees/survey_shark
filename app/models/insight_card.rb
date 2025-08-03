class InsightCard < ApplicationRecord
  belongs_to :project
  belongs_to :conversation, optional: true

  validates :theme, presence: true
  validates :severity, numericality: { in: 1..5 }
  validates :confidence_label, inclusion: { in: %w[L M H] }

  # Ensure evidence is always an array
  def evidence
    super || []
  end
end
