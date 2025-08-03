class Participant < ApplicationRecord
  belongs_to :project
  has_many :conversations, dependent: :destroy

  validates :age, numericality: { in: 0..120, allow_blank: true }
  validates :anon_hash, presence: true

  # Custom validation for required custom attributes
  validate :validate_required_custom_attributes

  private

  def validate_required_custom_attributes
    return unless project&.custom_attributes&.any?

    project.custom_attributes.each do |attr|
      if attr["required"] && (custom_attributes.nil? || custom_attributes[attr["key"]].blank?)
        errors.add(:base, "#{attr['label']}は必須項目です")
      end
    end
  end
end
