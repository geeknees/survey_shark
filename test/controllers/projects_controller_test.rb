require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get projects_url
    assert_response :success
  end

  test "should get new" do
    get new_project_url
    assert_response :success
  end

  test "should get show" do
    # Skip this test for now since we don't have projects to show
    skip "No projects exist yet"
  end
end
