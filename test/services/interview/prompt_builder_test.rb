# ABOUTME: Tests prompt builder system and behavior prompts across states.
# ABOUTME: Validates must-ask and summary interpolations for LLM guidance.
require "test_helper"
require_relative "../../../app/services/interview"
require_relative "../../../app/services/interview/prompt_builder"

class Interview::PromptBuilderTest < ActiveSupport::TestCase
  def setup
    @project = projects(:one)
    @prompt_builder = Interview::PromptBuilder.new(@project)
  end

  test "generates system prompt with project details" do
    @project.update!(
      goal: "Understand user pain points",
      tone: "polite_soft",
      limits: { "max_deep" => 5 },
      must_ask: [ "age", "location" ],
      never_ask: [ "income", "personal details" ]
    )

    system_prompt = @prompt_builder.system_prompt

    assert_includes system_prompt, "優しく丁寧な口調"
    assert_includes system_prompt, "5回程度"
    assert_includes system_prompt, "Understand user pain points"
    assert_includes system_prompt, "age"
    assert_includes system_prompt, "location"
    assert_includes system_prompt, "income"
    assert_includes system_prompt, "personal details"
  end

  test "generates appropriate behavior prompts for each state" do
    states_and_keywords = {
      "intro" => [ "課題", "不便", "3つまで" ],
      "enumerate" => [ "他に", "課題" ],
      "recommend" => [ "重要" ],
      "choose" => [ "選んで" ],
      "deepening" => [ "詳しく" ],
      "summary_check" => [ "まとめ", "確認" ]
    }

    states_and_keywords.each do |state, keywords|
      prompt = @prompt_builder.behavior_prompt_for_state(state)

      keywords.each do |keyword|
        assert_includes prompt, keyword, "State #{state} should include keyword #{keyword}"
      end
    end
  end

  test "generates must_ask prompt with item and followup hint" do
    prompt = @prompt_builder.behavior_prompt_for_state(
      "must_ask",
      0,
      must_ask_item: "年齢",
      must_ask_followup: true
    )

    assert_includes prompt, "必ず聞く項目: 年齢"
    assert_includes prompt, "追質問"
  end

  test "handles different tone settings" do
    tones = [ "polite_soft", "polite_firm", "casual_soft" ]

    tones.each do |tone|
      @project.update!(tone: tone)
      prompt = @prompt_builder.system_prompt

      assert prompt.present?, "Should generate prompt for tone #{tone}"
      assert_includes prompt, "口調", "Should mention tone in prompt"
    end
  end

  test "handles empty must_ask and never_ask arrays" do
    @project.update!(must_ask: [], never_ask: [])

    system_prompt = @prompt_builder.system_prompt

    assert system_prompt.present?
    # Should not crash and should still generate a valid prompt
  end

  test "interpolates summary in summary_check prompt" do
    prompt = @prompt_builder.behavior_prompt_for_state("summary_check")

    assert_includes prompt, "{summary}"
  end

  test "interpolates most_important in recommend prompt" do
    prompt = @prompt_builder.behavior_prompt_for_state("recommend")

    assert_includes prompt, "{most_important}"
  end
end
