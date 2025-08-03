require "application_system_test_case"

class ProjectsTest < ApplicationSystemTestCase
  setup do
    @admin = admins(:one)
    sign_in_as @admin
  end

  test "creating a project with valid params and seeing it in the list" do
    visit projects_path
    
    click_on "New Project"
    
    fill_in "Name", with: "Test Survey Project"
    fill_in "Goal/Description", with: "This is a test project for user research"
    fill_in "project[must_ask_text]", with: "User pain points\nDaily workflows"
    fill_in "project[never_ask_text]", with: "Personal information\nSalary details"
    select "Polite Soft", from: "Tone"
    select "Active", from: "Status"
    fill_in "Max Responses", with: "100"
    fill_in "project[limits][max_turns]", with: "15"
    fill_in "project[limits][max_deep]", with: "3"
    
    click_on "Create Project"
    
    # Should be redirected to the project show page
    assert_text "Test Survey Project"
    assert_text "Active"
    assert_text "Max responses: 100"
    assert_text "User pain points"
    assert_text "Daily workflows"
    assert_text "Personal information"
    assert_text "Salary details"
    
    # Go back to index and verify it's listed
    click_on "Back to Projects"
    assert_text "Test Survey Project"
    assert_text "Active"
  end

  test "editing a project" do
    project = Project.create!(
      name: "Original Project", 
      goal: "Original goal",
      status: "draft",
      max_responses: 50
    )
    
    visit project_path(project)
    click_on "Edit"
    
    fill_in "Name", with: "Updated Project Name"
    fill_in "Goal/Description", with: "Updated project goal"
    select "Active", from: "Status"
    fill_in "Max Responses", with: "75"
    
    click_on "Update Project"
    
    assert_text "Updated Project Name"
    assert_text "Updated project goal"
    assert_text "Active"
    assert_text "Max responses: 75"
  end

  test "state helpers work correctly" do
    draft_project = Project.create!(name: "Draft Project", status: "draft", max_responses: 50)
    active_project = Project.create!(name: "Active Project", status: "active", max_responses: 50)
    closed_project = Project.create!(name: "Closed Project", status: "closed", max_responses: 50)
    
    assert draft_project.draft?
    assert_not draft_project.active?
    assert_not draft_project.closed?
    
    assert_not active_project.draft?
    assert active_project.active?
    assert_not active_project.closed?
    
    assert_not closed_project.draft?
    assert_not closed_project.active?
    assert closed_project.closed?
  end

  private

  def sign_in_as(admin)
    visit new_session_path
    fill_in "email_address", with: admin.email_address
    fill_in "password", with: "password123"
    click_on "Sign in"
  end
end