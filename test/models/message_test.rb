require "test_helper"

class MessageTest < ActiveSupport::TestCase
  def setup
    @project = Project.create!(name: "Test Project")
    @conversation = Conversation.create!(project: @project)
  end

  test "valid with defaults" do
    msg = Message.new(conversation: @conversation, content: "Hello")
    assert msg.valid?
    assert_equal "user", msg.role
    assert_equal({}, msg.meta)
  end

  test "invalid without content" do
    msg = Message.new(conversation: @conversation)
    refute msg.valid?
    assert_includes msg.errors[:content], "can't be blank"
  end

  test "enum roles" do
    m1 = Message.create!(conversation: @conversation, content: "Hi", role: :user)
    m2 = Message.create!(conversation: @conversation, content: "Hi there", role: :assistant)
    assert m1.user?
    assert m2.assistant?
  end
end
