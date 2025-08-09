require "test_helper"

class ParticipantTest < ActiveSupport::TestCase
  def setup
    @project = Project.create!(name: "Test Project")
  end

  test "valid with anon_hash only" do
    p = Participant.new(project: @project, anon_hash: Security::TokenGenerator.generate_anon_hash)
    assert p.valid?
  end

  test "age validation allows blank and within range" do
    p = Participant.new(project: @project, anon_hash: "abcd", age: 25)
    assert p.valid?
    p.age = nil
    assert p.valid?
    p.age = 130
    refute p.valid?
  end

  test "custom required attributes are validated" do
    # Stub project.custom_attributes to simulate required field
    project = @project
    def project.custom_attributes
      [ { "key" => "dept", "label" => "部署", "required" => true } ]
    end
    participant = Participant.new(project: project, anon_hash: "abcd", custom_attributes: {})
    refute participant.valid?
    assert_includes participant.errors.full_messages, "部署は必須項目です"
    participant.custom_attributes = { "dept" => "Sales" }
    assert participant.valid?
  end
end
