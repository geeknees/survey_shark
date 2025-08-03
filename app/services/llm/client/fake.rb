class LLM::Client::Fake
  def initialize(responses: nil)
    @responses = responses || default_responses
    @call_count = 0
  end

  def generate_response(system_prompt:, behavior_prompt:, conversation_history:, user_message:)
    response = @responses[@call_count % @responses.length]
    @call_count += 1
    
    # Simulate some processing time
    sleep(0.1) if Rails.env.development?
    
    response
  end

  def stream_chat(messages:, **opts, &block)
    # For streaming, we'll simulate token-by-token delivery
    response = generate_response(
      system_prompt: "",
      behavior_prompt: "",
      conversation_history: messages,
      user_message: messages.last&.dig(:content) || ""
    )
    
    if block_given?
      # Simulate streaming by yielding chunks
      words = response.split(" ")
      words.each_with_index do |word, index|
        chunk = index == words.length - 1 ? word : "#{word} "
        yield(chunk)
        sleep(0.05) if Rails.env.development? # Simulate network delay
      end
    end
    
    response
  end

  private

  def default_responses
    [
      "ありがとうございます。日常生活で感じている課題や不便なことを教えてください。どんな小さなことでも構いません。",
      "なるほど、それは大変ですね。他にも何か困っていることはありますか？",
      "お聞かせいただいた中で、特に重要だと思われるのはその課題のようですが、いかがでしょうか？",
      "ありがとうございます。その課題について、もう少し詳しく教えてください。具体的にはどのような場面で困っていますか？",
      "詳しくお話しいただき、ありがとうございます。さらに詳しく、その時の状況や感じたことを教えてください。",
      "これまでのお話をまとめさせていただきます。主な課題として挙げていただいたのは、日常生活での不便な点についてですね。この内容で間違いありませんか？",
      "ご協力いただき、ありがとうございました。貴重なお話をお聞かせいただけました。"
    ]
  end
end