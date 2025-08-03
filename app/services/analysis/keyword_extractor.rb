class Analysis::KeywordExtractor
  def extract_keywords(tokens)
    # Simple RAKE-like keyword extraction
    # RAKE = Rapid Automatic Keyword Extraction
    
    # Stop words (common Japanese words to ignore)
    stop_words = %w[
      です ます した する ある いる から まで について
      この その あの どの これ それ あれ どれ
      私 僕 俺 あなた 彼 彼女 我々 みんな
      とても 非常 かなり 少し ちょっと
      でも しかし だから そして また
    ]
    
    # Filter out stop words
    content_tokens = tokens.reject { |token| stop_words.include?(token) }
    
    # Calculate word scores based on frequency and co-occurrence
    word_scores = calculate_word_scores(content_tokens)
    
    # Extract phrases (sequences of content words)
    phrases = extract_phrases(content_tokens, stop_words)
    
    # Score phrases
    phrase_scores = score_phrases(phrases, word_scores)
    
    # Return top keywords (both single words and phrases)
    top_words = word_scores.sort_by { |_, score| -score }.first(10).map(&:first)
    top_phrases = phrase_scores.sort_by { |_, score| -score }.first(5).map(&:first)
    
    (top_words + top_phrases).uniq.first(15)
  end

  private

  def calculate_word_scores(tokens)
    # Calculate frequency
    frequency = tokens.each_with_object(Hash.new(0)) { |token, hash| hash[token] += 1 }
    
    # Calculate degree (co-occurrence with other words)
    degree = Hash.new(0)
    tokens.each_with_index do |token, i|
      # Look at surrounding context (±2 words)
      context_start = [i - 2, 0].max
      context_end = [i + 2, tokens.length - 1].min
      
      (context_start..context_end).each do |j|
        next if i == j
        degree[token] += 1
      end
    end
    
    # RAKE score = degree / frequency
    scores = {}
    frequency.each do |word, freq|
      scores[word] = degree[word].to_f / freq
    end
    
    scores
  end

  def extract_phrases(tokens, stop_words)
    phrases = []
    current_phrase = []
    
    tokens.each do |token|
      if stop_words.include?(token)
        if current_phrase.length > 1
          phrases << current_phrase.join('')
        end
        current_phrase = []
      else
        current_phrase << token
      end
    end
    
    # Don't forget the last phrase
    if current_phrase.length > 1
      phrases << current_phrase.join('')
    end
    
    phrases
  end

  def score_phrases(phrases, word_scores)
    phrase_scores = {}
    
    phrases.each do |phrase|
      # Simple approach: sum of individual word scores
      # In real RAKE, this would be more sophisticated
      words_in_phrase = phrase.scan(/.{1,3}/)  # Simple tokenization
      score = words_in_phrase.sum { |word| word_scores[word] || 0 }
      phrase_scores[phrase] = score
    end
    
    phrase_scores
  end
end