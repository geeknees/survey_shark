class Message < ApplicationRecord
  belongs_to :conversation

  validates :content, presence: true
  validates :role, inclusion: { in: [0, 1] } # 0 = user, 1 = assistant

  enum role: { user: 0, assistant: 1 }
end
