require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  def setup
    @project = Project.create!(name: "Test Project")
  end

  test "valid with required associations and default state" do
    convo = Conversation.new(project: @project)
    assert convo.valid?, convo.errors.full_messages
    assert_equal "intro", convo.state
    assert_equal({}, convo.meta)
  end

  test "invalid with wrong state" do
    convo = Conversation.new(project: @project, state: "whatever")
    refute convo.valid?
    assert_includes convo.errors[:state], "is not included in the list"
  end

  test "associations" do
    convo = Conversation.create!(project: @project)
    assert_respond_to convo, :messages
    assert_respond_to convo, :insight_cards
  end
end
