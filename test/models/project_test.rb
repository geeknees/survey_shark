require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "should be valid with required attributes" do
    project = Project.new(name: "Test Project")
    assert project.valid?
  end

  test "should require name" do
    project = Project.new
    assert_not project.valid?
    assert_includes project.errors[:name], "can't be blank"
  end

  test "should have default values" do
    project = Project.create!(name: "Test Project")
    assert_equal [], project.must_ask
    assert_equal [], project.never_ask
    assert_equal "polite_soft", project.tone
    assert_equal({ "max_turns" => 12, "max_deep" => 2 }, project.limits)
    assert_equal "draft", project.status
    assert_equal 50, project.max_responses
  end

  test "should validate status inclusion" do
    project = Project.new(name: "Test", status: "invalid")
    assert_not project.valid?
    assert_includes project.errors[:status], "is not included in the list"
  end

  test "should validate tone inclusion" do
    project = Project.new(name: "Test", tone: "invalid")
    assert_not project.valid?
    assert_includes project.errors[:tone], "is not included in the list"
  end

  test "should validate max_responses is positive" do
    project = Project.new(name: "Test", max_responses: 0)
    assert_not project.valid?
    assert_includes project.errors[:max_responses], "must be greater than 0"
  end

  test "status helper methods" do
    project = Project.new(name: "Test")
    
    project.status = "draft"
    assert project.draft?
    assert_not project.active?
    assert_not project.closed?

    project.status = "active"
    assert_not project.draft?
    assert project.active?
    assert_not project.closed?

    project.status = "closed"
    assert_not project.draft?
    assert_not project.active?
    assert project.closed?
  end

  test "should have associations" do
    project = Project.create!(name: "Test Project")
    assert_respond_to project, :invite_links
    assert_respond_to project, :participants
    assert_respond_to project, :conversations
    assert_respond_to project, :insight_cards
  end
end
