# ABOUTME: Tests must-ask manager clarity detection and sequencing behavior.
# ABOUTME: Ensures unclear answers are recognized without blocking real replies.
require "test_helper"

class Interview::MustAskManagerTest < ActiveSupport::TestCase
  test "treats short unclear replies as unclear" do
    project = projects(:one)
    manager = Interview::MustAskManager.new(project, {})

    assert manager.unclear_answer?("ない")
    assert manager.unclear_answer?("わからない")
  end

  test "does not treat normal sentences containing ない as unclear" do
    project = projects(:one)
    manager = Interview::MustAskManager.new(project, {})

    refute manager.unclear_answer?("キッチンではなくリビングで起きました。")
    refute manager.unclear_answer?("最近は夜に起きることが多いです。")
  end

  test "advances after reaching followup limit" do
    project = projects(:one)
    project.update!(must_ask: [ "年齢" ])
    meta = { "must_ask_index" => 0, "must_ask_followup_count" => 2 }
    manager = Interview::MustAskManager.new(project, meta)

    assert_equal "summary_check", manager.next_state_after_answer("わからない")

    updated_meta = manager.advance_meta_for_answer("わからない")
    assert_equal 1, updated_meta["must_ask_index"]
    assert_equal 0, updated_meta["must_ask_followup_count"]
    assert_equal false, updated_meta["must_ask_followup"]
  end
end
