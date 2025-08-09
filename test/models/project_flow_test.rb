require "test_helper"

class ProjectFlowTest < ActiveSupport::TestCase
  test "create project with text lists and limits" do
    project = Project.create!(
      name: "Flow Project",
      goal: "Understand users",
      must_ask: [ "Topic A", "Topic B" ],
      never_ask: [ "Secret" ],
      limits: { "max_turns" => 15, "max_deep" => 3 },
      status: "active",
      max_responses: 100
    )
    assert_equal [ "Topic A", "Topic B" ], project.must_ask
    assert_equal [ "Secret" ], project.never_ask
    assert_equal({ "max_turns" => 15, "max_deep" => 3 }, project.limits)
    assert project.active?
  end

  test "update project attributes" do
    project = Project.create!(name: "Orig", goal: "G", status: "draft")
    project.update!(name: "Updated", goal: "New goal", status: "active", max_responses: 75)
    project.reload
    assert_equal "Updated", project.name
    assert_equal "New goal", project.goal
    assert_equal 75, project.max_responses
    assert project.active?
  end

  test "auto close when reaching actual responses" do
    project = Project.create!(name: "Limit Test", status: "active", max_responses: 1)
  project.conversations.create!(state: "done", finished_at: Time.current)
    project.check_and_auto_close!
    assert project.closed?, "Project should auto close after reaching limit"
  end
end
