class Project < ApplicationRecord
  has_many :invite_links, dependent: :destroy
  has_many :participants, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :insight_cards, dependent: :destroy

  validates :name, presence: true
  validates :status, inclusion: { in: %w[draft active closed] }
  validates :tone, inclusion: { in: %w[polite_soft polite_firm casual_soft casual_firm] }
  validates :max_responses, presence: true, numericality: { greater_than: 0 }

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
end
