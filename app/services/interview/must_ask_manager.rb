# ABOUTME: Handles must-ask sequencing, follow-ups, and meta updates.
# ABOUTME: Provides deterministic must-ask question text and clarity checks.
module Interview
  class MustAskManager
    MAX_FOLLOWUPS = 3
    UNCLEAR_PATTERNS = [
      /\Aわからない\z/,
      /\A分からない\z/,
      /\A覚えてない\z/,
      /\A覚えていない\z/,
      /\A不明\z/,
      /\A特にない\z/,
      /\Aない\z/
    ].freeze

    def initialize(project, meta)
      @project = project
      @meta = meta || {}
    end

    def pending?
      must_ask_items.any? && current_index < must_ask_items.length
    end

    def current_item
      return nil unless pending?

      must_ask_items[current_index]
    end

    def followup?
      @meta["must_ask_followup"] == true
    end

    def start_meta
      next_meta = @meta.dup
      next_meta["must_ask_index"] = 0 unless next_meta.key?("must_ask_index")
      next_meta["must_ask_followup"] = false
      next_meta["must_ask_followup_count"] = 0
      next_meta
    end

    def advance_meta_for_answer(content)
      if unclear_answer?(content)
        followup_count = followup_count_after_answer
        return advance_after_followup_limit if followup_count >= MAX_FOLLOWUPS

        return @meta.merge(
          "must_ask_followup" => true,
          "must_ask_followup_count" => followup_count
        )
      end

      next_index = current_index + 1
      @meta.merge(
        "must_ask_index" => next_index,
        "must_ask_followup" => false
      )
    end

    def next_state_after_answer(content)
      if unclear_answer?(content)
        return "must_ask" if followup_count_after_answer < MAX_FOLLOWUPS
      end

      next_index = current_index + 1
      next_index < must_ask_items.length ? "must_ask" : "summary_check"
    end

    def question
      return "" if current_item.blank?

      if followup?
        "先ほどの「#{current_item}」について、もう少し詳しく教えていただけますか？"
      else
        "次に、「#{current_item}」について教えてください。"
      end
    end

    def unclear_answer?(content)
      text = content.to_s.strip
      return true if text.empty?
      return true if text.length <= 1

      UNCLEAR_PATTERNS.any? { |pattern| pattern.match?(text) }
    end

    private

    def must_ask_items
      Array(@project.must_ask)
    end

    def current_index
      @meta["must_ask_index"].to_i
    end

    def followup_count_after_answer
      @meta.fetch("must_ask_followup_count", 0).to_i + 1
    end

    def advance_after_followup_limit
      next_index = current_index + 1
      @meta.merge(
        "must_ask_index" => next_index,
        "must_ask_followup" => false,
        "must_ask_followup_count" => 0
      )
    end
  end
end
