require "test_helper"
require_relative "../../../app/services/analysis"
require_relative "../../../app/services/analysis/conversation_analyzer"
require_relative "../../../app/services/analysis/fake_llm_client"

class Analysis::ConversationAnalyzerTest < ActiveSupport::TestCase
  def setup
    @project = projects(:one)
    @participant = participants(:one)
    @conversation = conversations(:one)
    @conversation.update!(finished_at: Time.current)

    # Add test messages
    @conversation.messages.create!(role: :user, content: "コンピューターが遅くて困っています")
    @conversation.messages.create!(role: :user, content: "作業効率が悪くて大変です")
    @conversation.messages.create!(role: :assistant, content: "詳しく教えてください")

    @analyzer = Analysis::ConversationAnalyzer.new(@conversation, llm_client: Analysis::FakeLLMClient.new)
  end

  test "analyzes conversation and returns insights" do
    insights = @analyzer.analyze

    assert insights.any?

    insight = insights.first
    assert insight.theme.present?
    assert insight.jtbd.present?
    assert insight.severity.present?
    assert insight.message_frequency > 0
    assert insight.evidence.any?
  end

  test "ignores assistant messages" do
    insights = @analyzer.analyze

    # Should only count user messages (excluding skip messages)
    expected_message_count = @conversation.messages.where(role: 0).where.not(content: "[スキップ]").count
    assert_equal expected_message_count, insights.first.message_frequency
  end

  test "ignores skip messages" do
    @conversation.messages.create!(role: :user, content: "[スキップ]")

    insights = @analyzer.analyze

    # Skip message should not be counted
    expected_message_count = @conversation.messages.where(role: 0).where.not(content: "[スキップ]").count
    assert_equal expected_message_count, insights.first.message_frequency
  end

  test "returns empty array for conversations with no user messages" do
    @conversation.messages.where(role: 0).destroy_all

    insights = @analyzer.analyze

    assert_empty insights
  end

  test "handles LLM errors gracefully" do
    error_client = Class.new do
      def generate_response(**args)
        raise "LLM Error"
      end
    end

    analyzer = Analysis::ConversationAnalyzer.new(@conversation, llm_client: error_client.new)
    insights = analyzer.analyze

    # Should return fallback analysis
    assert insights.any?
    assert_equal "ユーザーの課題", insights.first.theme
  end

  test "uses fake client in test environment" do
    analyzer = Analysis::ConversationAnalyzer.new(@conversation)
    assert_instance_of Analysis::FakeLLMClient, analyzer.instance_variable_get(:@llm_client)
  end

  test "processes computer-related content appropriately" do
    @conversation.messages.where(role: 0).destroy_all
    @conversation.messages.create!(role: :user, content: "パソコンが重くて困っています")

    insights = @analyzer.analyze

    assert insights.any?
    insight = insights.first
    assert_includes insight.theme, "コンピューター"
  end

  test "processes work-related content appropriately" do
    @conversation.messages.where(role: 0).destroy_all
    @conversation.messages.create!(role: :user, content: "仕事の効率が悪いです")

    insights = @analyzer.analyze

    assert insights.any?
    insight = insights.first
    assert_includes insight.theme, "業務"
  end
end
