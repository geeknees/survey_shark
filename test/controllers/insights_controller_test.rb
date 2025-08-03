require "test_helper"

class InsightsControllerTest < ActionDispatch::IntegrationTest
  def setup
    sign_in_as admins(:one)
    @project = projects(:one)

    # Create some insight cards
    @insight1 = @project.insight_cards.create!(
      theme: "システムの使いやすさ",
      jtbds: "効率的に作業したい",
      severity: 4,
      freq_conversations: 5,
      freq_messages: 12,
      confidence_label: "H",
      evidence: [ "使いにくい", "操作が複雑" ]
    )

    @insight2 = @project.insight_cards.create!(
      theme: "パフォーマンス問題",
      jtbds: "スムーズに動作してほしい",
      severity: 3,
      freq_conversations: 3,
      freq_messages: 8,
      confidence_label: "M",
      evidence: [ "遅い", "重い" ]
    )
  end

  test "should get index" do
    get project_insights_path(@project)
    assert_response :success
    assert_select "h1", "インサイトボード"
  end

  test "index shows insights ordered by frequency" do
    get project_insights_path(@project)

    # Should show insights in frequency order (conversations desc, then messages desc)
    assert_select ".bg-blue-100", text: "#1"  # First insight should be ranked #1
    assert_select "h3", text: @insight1.theme
    assert_select "h3", text: @insight2.theme
  end

  test "index shows empty state when no insights" do
    @project.insight_cards.destroy_all

    get project_insights_path(@project)

    assert_select "h3", "まだインサイトがありません"
  end

  test "should get show" do
    get project_insight_path(@project, @insight1)
    assert_response :success
    assert_select "h1", @insight1.theme
  end

  test "show displays insight details" do
    get project_insight_path(@project, @insight1)

    assert_select "h1", @insight1.theme
    assert_select "p", text: @insight1.jtbds
    assert_select "blockquote", count: @insight1.evidence.length

    # Check severity stars
    assert_select "svg.text-red-500", count: @insight1.severity

    # Check stats
    assert_select "div", text: @insight1.freq_conversations.to_s
    assert_select "div", text: @insight1.freq_messages.to_s
    assert_select "span", text: @insight1.confidence_label
  end

  test "requires authentication" do
    sign_out

    get project_insights_path(@project)
    assert_redirected_to new_session_path
  end

  test "handles non-existent project" do
    assert_raises(ActiveRecord::RecordNotFound) do
      get project_insights_path(project_id: 999999)
    end
  end

  test "handles non-existent insight" do
    assert_raises(ActiveRecord::RecordNotFound) do
      get project_insight_path(@project, 999999)
    end
  end
end
