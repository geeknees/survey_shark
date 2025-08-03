class Message < ApplicationRecord
  belongs_to :conversation

  validates :content, presence: true
  validates :role, inclusion: { in: [0, 1] } # 0 = user, 1 = assistant

  # Role helpers
  def user?
    role == 0
  end

  def assistant?
    role == 1
  end
end
