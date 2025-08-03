require "test_helper"

class InviteLinkTest < ActiveSupport::TestCase
  def setup
    @project = Project.create!(name: "Test Project")
  end

  test "should be valid with project" do
    invite_link = InviteLink.new(project: @project)
    assert invite_link.valid?
  end

  test "should require project" do
    invite_link = InviteLink.new
    assert_not invite_link.valid?
    assert_includes invite_link.errors[:project], "must exist"
  end

  test "should generate token automatically" do
    invite_link = InviteLink.create!(project: @project)
    assert_not_nil invite_link.token
    assert invite_link.token.length > 20
  end

  test "should have default values" do
    invite_link = InviteLink.create!(project: @project)
    assert_equal true, invite_link.reusable
  end

  test "should validate token uniqueness" do
    invite_link1 = InviteLink.create!(project: @project)
    invite_link2 = InviteLink.new(project: @project, token: invite_link1.token)
    assert_not invite_link2.valid?
    assert_includes invite_link2.errors[:token], "has already been taken"
  end

  test "should belong to project" do
    invite_link = InviteLink.create!(project: @project)
    assert_equal @project, invite_link.project
  end
end
