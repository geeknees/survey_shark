class Participant < ApplicationRecord
  belongs_to :project
  has_many :conversations, dependent: :destroy

  validates :age, numericality: { in: 0..120 }, allow_nil: true
end
