class InviteLink < ApplicationRecord
  belongs_to :project

  validates :token, presence: true, uniqueness: true

  before_validation :generate_token, on: :create

  private

  def generate_token
    self.token ||= Security::TokenGenerator.generate_invite_token
  end
end
