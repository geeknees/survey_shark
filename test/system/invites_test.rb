require "application_system_test_case"

class InvitesTest < ApplicationSystemTestCase
  setup do
    @admin = admins(:one)
    @project = Project.create!(
      name: "User Research Survey",
      goal: "Understanding user pain points",
      status: "active",
      max_responses: 2
    )
  end

  test "admin can generate invite link and user can access consent page" do
    sign_in_as @admin

    # Admin generates invite link
    visit project_path(@project)
    assert_text "Generate a public link to share this survey"

    click_on "Generate Link"
    assert_text "Invite link generated successfully"

    # Should now show the invite link
    assert_text "Public Survey URL:"
    assert_text "Responses: 0/2"

    # Extract the invite URL from the page
    invite_input = find("input[readonly]")
    invite_url = invite_input.value

    # Sign out and visit the invite link as a public user
    visit new_session_path
    click_on "Sign out" if page.has_link?("Sign out")

    visit invite_url

    # Should see consent page
    assert_text "User Research Survey"
    assert_text "Understanding user pain points"
    assert_text "参加について"
    assert_button "同意して開始"
  end

  test "user can start survey and increment counter" do
    invite_link = @project.invite_links.create!

    visit invite_path(invite_link.token)
    assert_text "User Research Survey"

    click_on "同意して開始"

    # Should redirect back with success message (attributes page will come in next prompt)
    assert_text "Started! (Attributes page coming in next prompt)"

    # Check that counter was incremented
    @project.reload
    assert_equal 1, @project.responses_count
  end

  test "project auto-closes when max responses reached" do
    invite_link = @project.invite_links.create!
    @project.update!(responses_count: 1) # One response already

    visit invite_path(invite_link.token)
    click_on "同意して開始"

    # Project should now be closed
    @project.reload
    assert_equal "closed", @project.status
    assert_equal 2, @project.responses_count
  end

  test "closed project shows proper message" do
    invite_link = @project.invite_links.create!
    @project.update!(status: "closed")

    visit invite_path(invite_link.token)

    assert_text "アクセスできません"
    assert_text "募集は終了しました"
    assert_no_button "同意して開始"
  end

  test "draft project blocks access" do
    invite_link = @project.invite_links.create!
    @project.update!(status: "draft")

    visit invite_path(invite_link.token)

    assert_text "アクセスできません"
    assert_text "not yet active"
    assert_no_button "同意して開始"
  end

  private

  def sign_in_as(admin)
    visit new_session_path
    fill_in "email_address", with: admin.email_address
    fill_in "password", with: "password123"
    click_on "Sign in"
  end
end
