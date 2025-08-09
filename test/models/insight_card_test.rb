require "test_helper"

class InsightCardTest < ActiveSupport::TestCase
  def setup
    @project = Project.create!(name: "Test Project")
  end

  test "valid with minimal attributes" do
    card = InsightCard.new(project: @project, theme: "Slow computers", severity: 3, confidence_label: "M")
    assert card.valid?, card.errors.full_messages
    assert_equal [], card.evidence
  end

  test "requires theme" do
    card = InsightCard.new(project: @project, severity: 2, confidence_label: "L")
    refute card.valid?
    assert_includes card.errors[:theme], "can't be blank"
  end

  test "severity range validation" do
    card = InsightCard.new(project: @project, theme: "X", severity: 10, confidence_label: "H")
    refute card.valid?
  end

  test "confidence label inclusion" do
    card = InsightCard.new(project: @project, theme: "X", severity: 2, confidence_label: "Z")
    refute card.valid?
    assert_includes card.errors[:confidence_label], "is not included in the list"
  end
end
