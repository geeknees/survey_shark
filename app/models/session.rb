class Session < ApplicationRecord
  belongs_to :admin, foreign_key: :user_id
end
