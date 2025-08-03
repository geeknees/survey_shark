require "test_helper"

class ProjectKpisTest < ActiveSupport::TestCase
  def setup
    @project = projects(:one)
    @kpis = ProjectKpis.new(@project)
  end

  test "calculates total responses correctly" do
    # Create finished conversations
    2.times do |i|
      conversation = @project.conversations.create!(
        participant: participants(:one),
        state: "done",
        started_at: 1.hour.ago,
        finished_at: Time.current
      )
    end
    
    assert_equal 2, @kpis.total_responses
  end

  test "calculates remaining slots correctly" do
    @project.update!(max_responses: 5)
    
    # Create 2 finished conversations
    2.times do |i|
      @project.conversations.create!(
        participant: participants(:one),
        state: "done",
        started_at: 1.hour.ago,
        finished_at: Time.current
      )
    end
    
    kpis = ProjectKpis.new(@project.reload)
    assert_equal 3, kpis.remaining_slots
  end

  test "remaining slots never goes below zero" do
    @project.update!(max_responses: 2)
    
    # Create 5 finished conversations (more than max)
    5.times do |i|
      @project.conversations.create!(
        participant: participants(:one),
        state: "done",
        started_at: 1.hour.ago,
        finished_at: Time.current
      )
    end
    
    kpis = ProjectKpis.new(@project.reload)
    assert_equal 0, kpis.remaining_slots
  end

  test "calculates strong pain rate correctly" do
    # Create conversations with high severity insights
    conversation1 = @project.conversations.create!(
      participant: participants(:one),
      state: "done",
      finished_at: Time.current
    )
    
    conversation2 = @project.conversations.create!(
      participant: participants(:one),
      state: "done",
      finished_at: Time.current
    )
    
    # Create insight cards with different severities
    @project.insight_cards.create!(
      conversation: conversation1,
      theme: "High severity issue",
      jtbds: "Fix urgent problem",
      severity: 5,
      freq_conversations: 1,
      freq_messages: 1,
      confidence_label: "H",
      evidence: ["Very serious problem"]
    )
    
    @project.insight_cards.create!(
      conversation: conversation2,
      theme: "Low severity issue",
      jtbds: "Minor improvement",
      severity: 2,
      freq_conversations: 1,
      freq_messages: 1,
      confidence_label: "L",
      evidence: ["Small issue"]
    )
    
    kpis = ProjectKpis.new(@project.reload)
    assert_equal 50.0, kpis.strong_pain_rate  # 1 out of 2 conversations has severity >= 4
  end

  test "calculates average turn count correctly" do
    conversation = @project.conversations.create!(
      participant: participants(:one),
      state: "done",
      finished_at: Time.current
    )
    
    # Add 3 user messages
    3.times do |i|
      conversation.messages.create!(role: 0, content: "User message #{i}")
    end
    
    # Add 2 assistant messages (should not be counted)
    2.times do |i|
      conversation.messages.create!(role: 1, content: "Assistant message #{i}")
    end
    
    kpis = ProjectKpis.new(@project.reload)
    assert_equal 3.0, kpis.average_turn_count
  end

  test "handles zero conversations gracefully" do
    empty_project = Project.create!(
      name: "Empty Project",
      max_responses: 10,
      status: "active"
    )
    
    kpis = ProjectKpis.new(empty_project)
    
    assert_equal 0, kpis.total_responses
    assert_equal 0.0, kpis.strong_pain_rate
    assert_equal 0.0, kpis.average_turn_count
    assert_equal 10, kpis.remaining_slots
  end

  test "detects when project is at limit" do
    @project.update!(max_responses: 2)
    
    # Create exactly max_responses conversations
    2.times do |i|
      @project.conversations.create!(
        participant: participants(:one),
        state: "done",
        finished_at: Time.current
      )
    end
    
    kpis = ProjectKpis.new(@project.reload)
    assert kpis.is_at_limit?
  end

  test "detects when project should auto close" do
    @project.update!(status: "active", max_responses: 1)
    
    # Create max_responses conversations
    @project.conversations.create!(
      participant: participants(:one),
      state: "done",
      finished_at: Time.current
    )
    
    kpis = ProjectKpis.new(@project.reload)
    assert kpis.should_auto_close?
  end

  test "should not auto close if project is not active" do
    @project.update!(status: "draft", max_responses: 1)
    
    @project.conversations.create!(
      participant: participants(:one),
      state: "done",
      finished_at: Time.current
    )
    
    kpis = ProjectKpis.new(@project.reload)
    refute kpis.should_auto_close?
  end
end