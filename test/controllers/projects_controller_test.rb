require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = admins(:one)
    sign_in @admin
  end

  test "should get index" do
    get projects_url
    assert_response :success
  end

  test "should get new" do
    get new_project_url
    assert_response :success
  end

  test "should create project" do
    assert_difference('Project.count') do
      post projects_url, params: { 
        project: { 
          name: "Test Project", 
          goal: "Test goal",
          tone: "polite_soft",
          status: "draft",
          max_responses: 50,
          limits: { max_turns: 12, max_deep: 2 }
        } 
      }
    end

    assert_redirected_to project_path(Project.last)
  end

  test "should show project" do
    project = Project.create!(name: "Test Project", max_responses: 50)
    get project_url(project)
    assert_response :success
  end

  test "should get edit" do
    project = Project.create!(name: "Test Project", max_responses: 50)
    get edit_project_url(project)
    assert_response :success
  end

  test "should update project" do
    project = Project.create!(name: "Test Project", max_responses: 50)
    patch project_url(project), params: { 
      project: { 
        name: "Updated Project",
        max_responses: 100
      } 
    }
    assert_redirected_to project_path(project)
  end

  test "should destroy project" do
    project = Project.create!(name: "Test Project", max_responses: 50)
    assert_difference('Project.count', -1) do
      delete project_url(project)
    end

    assert_redirected_to projects_url
  end

  private

  def sign_in(admin)
    post session_url, params: { email_address: admin.email_address, password: 'password123' }
  end
end
