class Project < ApplicationRecord
  has_many :invite_links, dependent: :destroy
  has_many :participants, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :insight_cards, dependent: :destroy

  validates :name, presence: true
  validates :initial_question, presence: true
  validates :status, inclusion: { in: %w[draft active closed] }
  validates :tone, inclusion: { in: %w[polite_soft polite_firm casual_soft casual_firm] }
  validates :max_responses, presence: true, numericality: { greater_than: 0 }

  # For MVP, we'll store custom attributes in a simple format
  # This is a placeholder - in a real app you might want a separate CustomAttribute model
  def custom_attributes
    # Return empty array for now - this will be enhanced when we add project configuration
    []
  end

  # Status helpers
  def draft?
    status == "draft"
  end

  def active?
    status == "active"
  end

  def closed?
    status == "closed"
  end

  # Calculate actual responses count (finished conversations)
  def actual_responses_count
    conversations.where.not(finished_at: nil).count
  end

  # Auto-close project if response limit reached
  def check_and_auto_close!
    if active? && actual_responses_count >= max_responses
      update!(status: "closed")
    end
  end
end
