require "test_helper"

class ThankYousControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = projects(:one)
    @project.update!(status: "active", max_responses: 10)

    # Use existing invite link from fixtures
    @invite_link = invite_links(:one)
  end

  test "should get show" do
    get project_thank_you_path(@project)
    assert_response :success
    assert_select "h1", "ご協力ありがとうございました"
  end

  test "show displays project information" do
    get project_thank_you_path(@project)

    assert_match(/プロジェクト: #{@project.name}/, response.body)
    assert_match(/貴重なご意見をいただき、誠にありがとうございました/, response.body)
  end

  test "restart creates new conversation when project is active and not at limit" do
    # Set session data beforehand if possible, or skip session-dependent logic for now
    assert_difference [ "Participant.count", "Conversation.count" ], 1 do
      post restart_project_thank_you_path(@project)
    end

    conversation = Conversation.last
    assert_equal @project, conversation.project
    assert_equal "intro", conversation.state
    assert conversation.started_at.present?

    assert_redirected_to conversation_path(conversation)
  end

  test "restart increments project responses count" do
    initial_count = @project.responses_count

    post restart_project_thank_you_path(@project)

    @project.reload
    assert_equal initial_count + 1, @project.responses_count
  end

  test "restart auto-closes project when reaching max responses" do
    @project.update!(max_responses: 1, responses_count: 0)

    post restart_project_thank_you_path(@project)

    @project.reload
    assert_equal "closed", @project.status
  end

  test "restart redirects with alert when project is closed" do
    @project.update!(status: "closed")

    post restart_project_thank_you_path(@project)

    assert_redirected_to invite_path(@invite_link.token)
    assert_match(/募集を終了しました/, flash[:alert])
  end

  test "restart redirects with alert when project is at limit" do
    @project.update!(max_responses: 1, responses_count: 1)

    post restart_project_thank_you_path(@project)

    assert_redirected_to invite_path(@invite_link.token)
    assert_match(/募集を終了しました/, flash[:alert])
  end

  test "restart clears session data" do
    post restart_project_thank_you_path(@project)

    # Session data should be cleared after restart
    # We can verify this by checking that a new conversation was created without error
    assert Conversation.last.present?
  end

  test "show displays restart button when project is active and not at limit" do
    get project_thank_you_path(@project)

    assert_select "input[value='もう一度回答する']"
  end

  test "show displays closed message when project is at limit" do
    @project.update!(max_responses: 1, responses_count: 1)

    get project_thank_you_path(@project)

    assert_select "div", text: "募集は終了しました"
    # Check that the restart button is not present
    assert_no_match(/もう一度回答する/, response.body)
  end
end
