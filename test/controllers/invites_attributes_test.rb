require "test_helper"

class InvitesAttributesTest < ActionDispatch::IntegrationTest
  setup do
    @project = Project.create!(name: "Test Project", status: "active", max_responses: 3)
    @invite_link = @project.invite_links.create!
  end

  test "should show attributes form" do
    get invite_attributes_path(@invite_link.token)
    assert_response :success
    assert_select "h1", "基本情報の入力"
    assert_select "input[name='participant[age]']"
    assert_select "input[type='submit'][value='アンケートを開始']"
  end

  test "should create participant with valid age" do
    assert_difference('Participant.count', 1) do
      assert_difference('Conversation.count', 1) do
        post invite_create_participant_path(@invite_link.token), params: {
          participant: { age: 25 }
        }
      end
    end

    participant = Participant.last
    assert_equal 25, participant.age
    assert_equal @project, participant.project
    assert_not_nil participant.anon_hash

    conversation = Conversation.last
    assert_equal @project, conversation.project
    assert_equal participant, conversation.participant
    assert_equal "intro", conversation.state
    assert_not_nil conversation.started_at
    assert_not_nil conversation.ip
    assert_not_nil conversation.user_agent
  end

  test "should create participant with blank age" do
    assert_difference('Participant.count', 1) do
      post invite_create_participant_path(@invite_link.token), params: {
        participant: { age: "" }
      }
    end

    participant = Participant.last
    assert_nil participant.age
  end

  test "should reject invalid age" do
    assert_no_difference('Participant.count') do
      post invite_create_participant_path(@invite_link.token), params: {
        participant: { age: 150 }
      }
    end
    assert_response :unprocessable_entity
    assert_select ".text-red-700", /Age/
  end

  test "should reject negative age" do
    assert_no_difference('Participant.count') do
      post invite_create_participant_path(@invite_link.token), params: {
        participant: { age: -5 }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should create participant with custom attributes" do
    # Mock custom attributes for this test
    @project.define_singleton_method(:custom_attributes) do
      [
        { 'key' => 'occupation', 'label' => '職業', 'required' => false },
        { 'key' => 'department', 'label' => '部署', 'required' => true }
      ]
    end

    assert_difference('Participant.count', 1) do
      post invite_create_participant_path(@invite_link.token), params: {
        participant: { 
          age: 30,
          custom_attributes: {
            'occupation' => 'Engineer',
            'department' => 'Development'
          }
        }
      }
    end

    participant = Participant.last
    assert_equal 'Engineer', participant.custom_attributes['occupation']
    assert_equal 'Development', participant.custom_attributes['department']
  end

  # TODO: Re-enable when custom attributes are fully implemented
  # test "should validate required custom attributes" do
  #   # Create a new project instance for this test to avoid interference
  #   test_project = Project.create!(name: "Test Project", status: "active", max_responses: 3)
  #   test_invite_link = test_project.invite_links.create!
  #   
  #   # Mock custom attributes with required field
  #   test_project.define_singleton_method(:custom_attributes) do
  #     [{ 'key' => 'department', 'label' => '部署', 'required' => true }]
  #   end
  #
  #   assert_no_difference('Participant.count') do
  #     post invite_create_participant_path(test_invite_link.token), params: {
  #       participant: { 
  #         age: 30,
  #         custom_attributes: { 'department' => '' }
  #       }
  #     }
  #   end
  #   assert_response :unprocessable_entity
  #   assert_select ".text-red-700", /部署は必須項目です/
  # end

  test "should generate unique anon_hash for each participant" do
    post invite_create_participant_path(@invite_link.token), params: {
      participant: { age: 25 }
    }
    first_hash = Participant.last.anon_hash

    # Create another participant
    post invite_create_participant_path(@invite_link.token), params: {
      participant: { age: 30 }
    }
    second_hash = Participant.last.anon_hash

    assert_not_equal first_hash, second_hash
    assert_equal 16, first_hash.length  # Should be 16 characters
    assert_equal 16, second_hash.length
  end
end