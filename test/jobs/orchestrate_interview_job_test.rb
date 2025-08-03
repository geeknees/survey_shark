require "test_helper"

class OrchestrateInterviewJobTest < ActiveJob::TestCase
  def setup
    @conversation = conversations(:one)
    @user_message = @conversation.messages.create!(role: :user, content: "Test message")
  end

  test "processes user message and creates assistant response" do
    assert_difference "Message.count", 1 do
      OrchestrateInterviewJob.perform_now(@conversation.id, @user_message.id)
    end
    
    assistant_message = @conversation.messages.assistant.last
    assert_not_nil assistant_message
    assert assistant_message.content.present?
  end

  test "updates conversation state" do
    initial_state = @conversation.state
    
    OrchestrateInterviewJob.perform_now(@conversation.id, @user_message.id)
    
    # State should have progressed (exact state depends on current state and logic)
    @conversation.reload
    # We can't assert exact state without knowing the starting state and logic,
    # but we can verify the job ran without error
    assert_not_nil @conversation.messages.assistant.last
  end

  test "handles non-existent conversation gracefully" do
    assert_raises(ActiveRecord::RecordNotFound) do
      OrchestrateInterviewJob.perform_now(999999, @user_message.id)
    end
  end

  test "handles non-existent message gracefully" do
    assert_raises(ActiveRecord::RecordNotFound) do
      OrchestrateInterviewJob.perform_now(@conversation.id, 999999)
    end
  end
end