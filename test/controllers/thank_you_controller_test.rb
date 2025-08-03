require "test_helper"

class ThankYouControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = projects(:one)
    @project.update!(status: "active", max_responses: 10)

    # Create invite link
    @invite_link = @project.invite_links.create!(
      token: SecureRandom.urlsafe_base64(32),
      reusable: true
    )
  end

  test "should get show" do
    get project_thank_you_path(@project)
    assert_response :success
    assert_select "h1", "ご協力ありがとうございました"
  end

  test "show displays project information" do
    get project_thank_you_path(@project)

    assert_select "p", text: /プロジェクト: #{@project.name}/
  end

  test "restart creates new conversation when project is active and not at limit" do
    # Set up session data
    post project_thank_you_path(@project), params: {}, session: {
      participant_age: 30,
      participant_attributes: { "hobby" => "reading" }
    }

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
    assert_match /募集を終了しました/, flash[:alert]
  end

  test "restart redirects with alert when project is at limit" do
    @project.update!(max_responses: 1, responses_count: 1)

    post restart_project_thank_you_path(@project)

    assert_redirected_to invite_path(@invite_link.token)
    assert_match /募集を終了しました/, flash[:alert]
  end

  test "restart clears session data" do
    post project_thank_you_path(@project), params: {}, session: {
      participant_age: 30,
      participant_attributes: { "hobby" => "reading" }
    }

    post restart_project_thank_you_path(@project)

    assert_nil session[:participant_age]
    assert_nil session[:participant_attributes]
  end

  test "show displays restart button when project is active and not at limit" do
    get project_thank_you_path(@project)

    assert_select "input[value='もう一度回答する']"
  end

  test "show displays closed message when project is at limit" do
    @project.update!(max_responses: 1)

    # Create a finished conversation to reach limit
    @project.conversations.create!(
      participant: participants(:one),
      state: "done",
      finished_at: Time.current
    )

    get project_thank_you_path(@project)

    assert_select "div", text: "募集は終了しました"
    assert_no_selector "input[value='もう一度回答する']"
  end
end
