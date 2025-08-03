require "application_system_test_case"

class AttributesTest < ApplicationSystemTestCase
  setup do
    @project = Project.create!(
      name: "User Research Survey",
      goal: "Understanding user pain points",
      status: "active",
      max_responses: 5
    )
    @invite_link = @project.invite_links.create!
  end

  test "consent to attributes to conversation flow" do
    visit invite_path(@invite_link.token)

    # Should see consent page
    assert_text "User Research Survey"
    assert_button "同意して開始"

    click_on "同意して開始"

    # Should be redirected to attributes page
    assert_text "基本情報の入力"
    assert_field "年齢"
    assert_button "アンケートを開始"

    # Fill in age
    fill_in "年齢", with: "28"

    click_on "アンケートを開始"

    # Should be redirected to conversation page
    assert_text "インタビュー"
    assert_text "[インタビュー開始]"

    # Verify participant was created
    participant = Participant.last
    assert_equal 28, participant.age
    assert_equal @project, participant.project
    assert_not_nil participant.anon_hash

    # Verify conversation was created
    conversation = Conversation.last
    assert_equal @project, conversation.project
    assert_equal participant, conversation.participant
    assert_equal "intro", conversation.state
  end

  test "attributes form with blank age" do
    visit invite_attributes_path(@invite_link.token)

    # Leave age blank and submit
    click_on "アンケートを開始"

    # Should be redirected to conversation page
    assert_text "インタビュー"

    participant = Participant.last
    assert_nil participant.age
  end

  test "attributes form validation for invalid age" do
    visit invite_attributes_path(@invite_link.token)

    # Enter invalid age as text (bypassing HTML5 validation)
    page.execute_script("document.querySelector('input[name=\"participant[age]\"]').value = '150'")

    click_on "アンケートを開始"

    # Should show validation error or stay on the same page
    assert_current_path invite_attributes_path(@invite_link.token)
  end
end
