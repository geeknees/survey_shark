require_relative "base"

module LLM
  module Client
    class OpenAI < Base
      MAX_RESPONSE_LENGTH = 400
      MAX_RETRIES = 1
      RETRY_SLEEP = 1

      def initialize(api_key: nil, model: "gpt-5.2", temperature: 0.2)
        @api_key = api_key || ENV["OPENAI_API_KEY"]
        @model = model
        @temperature = temperature

        raise ArgumentError, "OpenAI API key is required" if @api_key.blank?

        @client = ::OpenAI::Client.new(access_token: @api_key)
      end

      def generate_response(system_prompt:, behavior_prompt:, conversation_history:, user_message:)
        messages = build_messages(system_prompt, behavior_prompt, conversation_history, user_message)
        content = call_api_with_retry(messages)
        truncate_response(content)
      end

      def stream_chat(messages:, **opts, &block)
        formatted_messages = format_messages_for_api(messages)

        if block_given?
          stream_response(formatted_messages, &block)
        else
          # Non-streaming fallback
          content = call_api_with_retry(formatted_messages)
          truncate_response(content)
        end
      end

      private

      def call_api_with_retry(messages)
        retry_count = 0
        begin
          response = @client.chat(
            parameters: {
              model: @model,
              messages: messages,
              temperature: @temperature
            }
          )
          response.dig("choices", 0, "message", "content") || ""
        rescue ::OpenAI::Error, StandardError => e
          Rails.logger.error "OpenAI API error: #{e.message}"
          if retry_count < MAX_RETRIES
            retry_count += 1
            Rails.logger.info "Retrying OpenAI request (attempt #{retry_count + 1})"
            sleep(RETRY_SLEEP)
            retry
          end
          raise OpenAIError.new("API error after retry: #{e.message}")
        end
      end

      def build_messages(system_prompt, behavior_prompt, conversation_history, user_message)
        messages = []

        # System message
        messages << { role: "system", content: system_prompt } if system_prompt.present?

        # Conversation history
        conversation_history.each do |msg|
          messages << { role: msg[:role], content: msg[:content] }
        end

        # Current behavior prompt + user message
        messages << { role: "system", content: behavior_prompt } if behavior_prompt.present?
        messages << { role: "user", content: user_message }

        messages
      end

      def format_messages_for_api(messages)
        messages.map do |msg|
          { role: msg[:role], content: msg[:content] }
        end
      end

      def stream_response(messages, &block)
        accumulated_content = ""

        begin
          @client.chat(
            parameters: {
              model: @model,
              messages: messages,
              temperature: @temperature,
              stream: proc do |chunk, _bytesize|
                delta = chunk.dig("choices", 0, "delta", "content")

                if delta
                  accumulated_content += delta

                  # Check length limit
                  if accumulated_content.length > MAX_RESPONSE_LENGTH
                    truncated = truncate_response(accumulated_content)
                    remaining = truncated[accumulated_content.length - delta.length..-1]
                    yield(remaining) if remaining.present?
                    break
                  else
                    yield(delta)
                  end
                end
              end
            }
          )
        rescue => e
          # Fall back to non-streaming on any error
          Rails.logger.error "OpenAI streaming error: #{e.message}, falling back to non-streaming" if defined?(Rails)
          content = call_api_with_retry(messages)
          accumulated_content = content
          yield(truncate_response(content)) if block_given?
        end

        truncate_response(accumulated_content)
      end

      def truncate_response(content)
        return content if content.length <= MAX_RESPONSE_LENGTH

        # Try to truncate at sentence boundary
        truncated = content[0, MAX_RESPONSE_LENGTH]
        last_sentence_end = [ truncated.rindex("。"), truncated.rindex("？"), truncated.rindex("！") ].compact.max

        # If we found a sentence boundary and it's not too early in the text, use it
        if last_sentence_end && last_sentence_end >= 20  # At least 20 characters
          truncated = truncated[0, last_sentence_end + 1]
        end

        truncated
      end

      class OpenAIError < StandardError; end
    end
  end
end
