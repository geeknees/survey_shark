require "test_helper"

class InvitesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = Project.create!(name: "Test Project", status: "active", max_responses: 3)
    @invite_link = @project.invite_links.create!
  end

  test "should show consent page for active project" do
    get invite_path(@invite_link.token)
    assert_response :success
    assert_select "h1", @project.name
    assert_select "input[value='同意して開始']"
  end

  test "should block draft project" do
    @project.update!(status: "draft")
    get invite_path(@invite_link.token)
    assert_response :success
    assert_select "h1", "アクセスできません"
    assert_match "not yet active", response.body
  end

  test "should block closed project" do
    @project.update!(status: "closed")
    get invite_path(@invite_link.token)
    assert_response :success
    assert_select "h1", "アクセスできません"
    assert_match "募集は終了しました", response.body
  end

  test "should block when max responses reached" do
    @project.update!(responses_count: 3) # Equal to max_responses
    get invite_path(@invite_link.token)
    assert_response :success
    assert_select "h1", "アクセスできません"
    assert_match "募集は終了しました", response.body
  end

  test "should auto-close project when max responses reached" do
    @project.update!(responses_count: 2) # One less than max
    assert_equal "active", @project.status

    post invite_start_path(@invite_link.token)

    @project.reload
    assert_equal 3, @project.responses_count
    assert_equal "closed", @project.status
  end

  test "should increment responses count on start" do
    assert_difference("@project.reload.responses_count", 1) do
      post invite_start_path(@invite_link.token)
    end
    assert_redirected_to invite_attributes_path(@invite_link.token)
  end

  test "should return 404 for invalid token" do
    get invite_path("invalid_token")
    assert_response :not_found
    assert_select "h1", "ページが見つかりません"
  end

  test "should handle over limit case by auto-closing" do
    @project.update!(responses_count: 3) # Already at max
    get invite_path(@invite_link.token)

    @project.reload
    assert_equal "closed", @project.status
  end
end
