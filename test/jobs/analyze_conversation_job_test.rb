require "test_helper"

class AnalyzeConversationJobTest < ActiveJob::TestCase
  def setup
    @project = projects(:one)
    @participant = participants(:one)
    @conversation = conversations(:one)
    @conversation.update!(finished_at: Time.current)

    # Add some user messages
    @conversation.messages.create!(role: :user, content: "コンピューターが遅くて困っています")
    @conversation.messages.create!(role: :user, content: "作業効率が悪くて大変です")
  end

  test "analyzes finished conversation and creates insight cards" do
    assert_difference "InsightCard.count", 1 do
      AnalyzeConversationJob.perform_now(@conversation.id)
    end

    insight = InsightCard.last
    assert_equal @project, insight.project
    assert insight.theme.present?
    assert insight.jtbds.present?
    assert insight.severity.present?
    assert insight.freq_conversations == 1
    assert insight.freq_messages > 0
    assert insight.confidence_label.present?
    assert insight.evidence.any?
  end

  test "skips analysis for unfinished conversations" do
    @conversation.update!(finished_at: nil)

    assert_no_difference "InsightCard.count" do
      AnalyzeConversationJob.perform_now(@conversation.id)
    end
  end

  test "merges insights with existing cards of same theme" do
    # Create existing insight card
    existing_card = @project.insight_cards.create!(
      theme: "コンピューターの性能問題",
      jtbds: "スムーズに作業したい",
      severity: 3,
      freq_conversations: 1,
      freq_messages: 2,
      confidence_label: "M",
      evidence: [ "既存の発言" ]
    )

    # Run analysis (should merge with existing card)
    AnalyzeConversationJob.perform_now(@conversation.id)

    existing_card.reload
    assert_equal 2, existing_card.freq_conversations
    assert existing_card.freq_messages > 2
    assert existing_card.evidence.length <= 2  # Should keep max 2 evidence
  end

  test "handles analysis errors gracefully" do
    # Mock analyzer to raise error
    mock_analyzer = Minitest::Mock.new
    mock_analyzer.expect(:analyze, nil) { raise "Analysis error" }

    Analysis::ConversationAnalyzer.stub(:new, mock_analyzer) do
      assert_nothing_raised do
        AnalyzeConversationJob.perform_now(@conversation.id)
      end
    end
  end

  test "calculates confidence labels correctly" do
    AnalyzeConversationJob.perform_now(@conversation.id)

    insight = InsightCard.last
    assert_includes [ "L", "M", "H" ], insight.confidence_label
  end

  test "handles conversations with no user messages" do
    # Remove all user messages
    @conversation.messages.where(role: 0).destroy_all

    assert_no_difference "InsightCard.count" do
      AnalyzeConversationJob.perform_now(@conversation.id)
    end
  end

  test "handles non-existent conversation gracefully" do
    assert_raises(ActiveRecord::RecordNotFound) do
      AnalyzeConversationJob.perform_now(999999)
    end
  end
end
