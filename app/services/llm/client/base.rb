class LLM::Client::Base
  def generate_response(system_prompt:, behavior_prompt:, conversation_history:, user_message:)
    raise NotImplementedError, "Subclasses must implement #generate_response"
  end

  def stream_chat(messages:, **opts, &block)
    raise NotImplementedError, "Subclasses must implement #stream_chat"
  end
end
