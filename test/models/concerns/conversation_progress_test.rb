require "test_helper"

class ConversationProgressTest < ActiveSupport::TestCase
  setup do
    @project = projects(:one)
    @conversation = conversations(:one)
  end

  test "user_message_count returns count of user messages" do
    initial_count = @conversation.user_message_count
    @conversation.messages.create!(role: :user, content: "User message 1")
    @conversation.messages.create!(role: :assistant, content: "Assistant message")
    @conversation.messages.create!(role: :user, content: "User message 2")

    assert_equal initial_count + 2, @conversation.user_message_count
  end

  test "assistant_message_count returns count of assistant messages" do
    initial_count = @conversation.assistant_message_count
    @conversation.messages.create!(role: :user, content: "User message")
    @conversation.messages.create!(role: :assistant, content: "Assistant message 1")
    @conversation.messages.create!(role: :assistant, content: "Assistant message 2")

    assert_equal initial_count + 2, @conversation.assistant_message_count
  end

  test "total_message_count returns total messages" do
    initial_count = @conversation.total_message_count
    @conversation.messages.create!(role: :user, content: "User message")
    @conversation.messages.create!(role: :assistant, content: "Assistant message")

    assert_equal initial_count + 2, @conversation.total_message_count
  end

  test "max_turns returns project limit or default" do
    @project.update!(limits: { "max_turns" => 15 })
    @conversation.reload
    assert_equal 15, @conversation.max_turns

    @project.update!(limits: {})
    @conversation.reload
    assert_equal 12, @conversation.max_turns
  end

  test "remaining_turns calculates correctly" do
    @project.update!(limits: { "max_turns" => 10 })
    @conversation.messages.create!(role: :user, content: "User message 1")
    @conversation.messages.create!(role: :user, content: "User message 2")

    assert_equal 8, @conversation.remaining_turns
  end

  test "should_finish? returns true when at turn limit" do
    @project.update!(limits: { "max_turns" => 1 })
    @conversation.messages.create!(role: :user, content: "User message")

    assert @conversation.should_finish?
  end

  test "should_finish? returns true when in done state" do
    @conversation.update!(state: "done")
    assert @conversation.should_finish?
  end

  test "progress_percentage calculates correctly" do
    @project.update!(limits: { "max_turns" => 10 })
    @conversation.messages.create!(role: :user, content: "User message 1")
    @conversation.messages.create!(role: :user, content: "User message 2")

    assert_equal 20, @conversation.progress_percentage
  end

  test "progress_percentage returns 100 for finished conversations" do
    @conversation.update!(finished_at: Time.current)
    assert_equal 100, @conversation.progress_percentage
  end

  test "progress_status returns correct status for each state" do
    @conversation.update!(state: "intro")
    assert_equal "開始", @conversation.progress_status

    @conversation.update!(state: "deepening")
    assert_equal "深掘り", @conversation.progress_status

    @conversation.update!(finished_at: Time.current)
    assert_equal "完了", @conversation.progress_status
  end
end
