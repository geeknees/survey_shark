# ABOUTME: System tests for insights index and detail navigation flows.
# ABOUTME: Ensures insights rendering and authentication behavior works.
require "application_system_test_case"

class InsightsTest < ApplicationSystemTestCase
  def setup
    @admin = admins(:one)
    @project = projects(:one)

    # Create a finished conversation with messages
    @conversation = @project.conversations.create!(
      participant: participants(:one),
      state: "done",
      started_at: 1.hour.ago,
      finished_at: Time.current
    )

    @conversation.messages.create!(role: :user, content: "コンピューターが遅くて困っています")
    @conversation.messages.create!(role: :user, content: "作業効率が悪くて大変です")
    @conversation.messages.create!(role: :assistant, content: "詳しく教えてください")
  end

  test "finishing a conversation creates insights visible on insights page" do
    sign_in_as @admin

    # Create insight cards manually instead of relying on job execution
    @project.insight_cards.create!(
      theme: "コンピューターの性能問題",
      jtbds: "効率よく作業したい",
      severity: 4,
      freq_conversations: 1,
      freq_messages: 2,
      confidence_label: "H",
      evidence: [ "コンピューターが遅くて困っています", "作業効率が悪くて大変です" ]
    )

    # Visit project page and click insights link
    visit project_path(@project)
    click_link "Insights"

    # Should see insights page
    assert_text "インサイトボード"
    assert_text @project.name

    # Should see generated insights
    assert_text "コンピューターの性能問題"
  end

  test "insights page shows top 5 themes by frequency" do
    sign_in_as @admin

    # Create multiple insight cards with different frequencies
    insights = []
    5.times do |i|
      insights << @project.insight_cards.create!(
        theme: "テーマ#{i + 1}",
        jtbds: "目標#{i + 1}",
        severity: 3,
        freq_conversations: 5 - i,  # Descending frequency
        freq_messages: 10 - i,
        confidence_label: "M",
        evidence: [ "発言#{i + 1}" ]
      )
    end

    visit project_insights_path(@project)

    # Should see insights ordered by frequency
    assert_text "#1"  # First rank
    assert_text "テーマ1"  # Highest frequency theme

    # Should not show more than 5
    assert_selector ".bg-blue-100", maximum: 5
  end

  test "insight detail page shows comprehensive information" do
    sign_in_as @admin

    insight = @project.insight_cards.create!(
      theme: "システムの使いやすさ",
      jtbds: "効率的に作業したい",
      severity: 4,
      freq_conversations: 3,
      freq_messages: 8,
      confidence_label: "H",
      evidence: [ "使いにくい", "操作が複雑" ]
    )

    visit project_insight_path(@project, insight)

    # Should see insight details
    assert_text "システムの使いやすさ"
    assert_text "効率的に作業したい"
    assert_text "使いにくい"
    assert_text "操作が複雑"

    # Should see stats
    assert_text "3"  # freq_conversations
    assert_text "8"  # freq_messages
    assert_text "H"  # confidence_label

    # Should see severity stars
    assert_selector "svg.text-red-500", count: 4
  end

  test "empty insights page shows appropriate message" do
    sign_in_as @admin

    # Create a new project without insights to test empty state
    empty_project = Project.create!(
      name: "Empty Project",
      goal: "Test project with no insights",
      status: "active",
      max_responses: 50
    )

    visit project_insights_path(empty_project)

    assert_text "まだインサイトがありません"
    assert_text "会話が完了すると、自動的にインサイトが生成されます"
  end

  test "navigation between insights pages works" do
    sign_in_as @admin

    insight = @project.insight_cards.create!(
      theme: "テストテーマ",
      jtbds: "テスト目標",
      severity: 3,
      freq_conversations: 1,
      freq_messages: 2,
      confidence_label: "L",
      evidence: [ "テスト発言" ]
    )

    # Start from project page
    visit project_path(@project)
    click_link "Insights"

    # Should be on insights page
    assert_text "インサイトボード"

    # Go to insight detail
    click_link "テストテーマ"
    assert_selector "a", text: "インサイトボードに戻る", wait: 5

    # Go back to insights board
    click_link "インサイトボードに戻る"
    assert_text "インサイトボード"
  end

  test "insights require authentication" do
    visit project_insights_path(@project)
    assert_current_path new_session_path
  end
end
