class Analysis::TextProcessor
  def normalize(text)
    # Basic text normalization
    normalized = text.dup

    # Remove extra whitespace
    normalized.gsub!(/\s+/, " ")

    # Remove special characters but keep Japanese punctuation
    normalized.gsub!(/[^\p{Hiragana}\p{Katakana}\p{Han}a-zA-Z0-9\s。、！？]/, "")

    # Trim
    normalized.strip
  end

  def tokenize(text)
    # Simple tokenization for Japanese text
    # In a real implementation, you would use TinySegmenter or MeCab
    # For now, we'll use a simple approach

    # Split on common Japanese punctuation and spaces
    tokens = text.split(/[。、！？\s]+/).reject(&:empty?)

    # Further split long tokens (simple heuristic)
    tokens.flat_map do |token|
      if token.length > 10
        # Split long tokens into smaller chunks
        token.scan(/.{1,5}/)
      else
        [ token ]
      end
    end.reject { |token| token.length < 2 }
  end
end
