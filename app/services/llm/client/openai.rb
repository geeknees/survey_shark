require "net/http"
require "json"

module LLM
  module Client
    class OpenAI < LLM::Client::Base
      API_URL = "https://api.openai.com/v1/chat/completions"
      MAX_RESPONSE_LENGTH = 400
      TIMEOUT_SECONDS = 30

      def initialize(api_key: nil, model: "gpt-4", temperature: 0.2)
        @api_key = api_key || ENV["OPENAI_API_KEY"]
    @model = model
    @temperature = temperature

    raise ArgumentError, "OpenAI API key is required" if @api_key.blank?
  end

  def generate_response(system_prompt:, behavior_prompt:, conversation_history:, user_message:)
    messages = build_messages(system_prompt, behavior_prompt, conversation_history, user_message)

    response = make_request(messages, stream: false)
    content = response.dig("choices", 0, "message", "content") || ""

    truncate_response(content)
  end

  def stream_chat(messages:, **opts, &block)
    formatted_messages = format_messages_for_api(messages)

    if block_given?
      stream_response(formatted_messages, &block)
    else
      # Non-streaming fallback
      response = make_request(formatted_messages, stream: false)
      content = response.dig("choices", 0, "message", "content") || ""
      truncate_response(content)
    end
  end

  private

  def build_messages(system_prompt, behavior_prompt, conversation_history, user_message)
    messages = []

    # System message
    if system_prompt.present?
      messages << { role: "system", content: system_prompt }
    end

    # Conversation history
    conversation_history.each do |msg|
      messages << { role: msg[:role], content: msg[:content] }
    end

    # Current behavior prompt + user message
    if behavior_prompt.present?
      messages << { role: "system", content: behavior_prompt }
    end

    messages << { role: "user", content: user_message }

    messages
  end

  def format_messages_for_api(messages)
    messages.map do |msg|
      { role: msg[:role], content: msg[:content] }
    end
  end

  def make_request(messages, stream: false, retry_count: 0)
    uri = URI(API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = TIMEOUT_SECONDS
    http.open_timeout = TIMEOUT_SECONDS

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@api_key}"
    request["Content-Type"] = "application/json"

    body = {
      model: @model,
      messages: messages,
      temperature: @temperature,
      max_tokens: 500,
      stream: stream
    }

    request.body = body.to_json

    begin
      response = http.request(request)

      if response.code == "200"
        JSON.parse(response.body)
      else
        handle_api_error(response, messages, retry_count)
      end
    rescue Net::TimeoutError, Net::OpenTimeout, Errno::ECONNREFUSED => e
      handle_network_error(e, messages, retry_count)
    rescue JSON::ParserError => e
      handle_parse_error(e, messages, retry_count)
    end
  end

  def stream_response(messages, &block)
    uri = URI(API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = TIMEOUT_SECONDS

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@api_key}"
    request["Content-Type"] = "application/json"

    body = {
      model: @model,
      messages: messages,
      temperature: @temperature,
      max_tokens: 500,
      stream: true
    }

    request.body = body.to_json

    accumulated_content = ""

    begin
      http.request(request) do |response|
        if response.code == "200"
          response.read_body do |chunk|
            chunk.split("\n").each do |line|
              next unless line.start_with?("data: ")

              data = line[6..-1].strip
              next if data == "[DONE]"

              begin
                parsed = JSON.parse(data)
                delta = parsed.dig("choices", 0, "delta", "content")

                if delta
                  accumulated_content += delta

                  # Check length limit
                  if accumulated_content.length > MAX_RESPONSE_LENGTH
                    # Truncate and stop streaming
                    truncated = truncate_response(accumulated_content)
                    remaining = truncated[accumulated_content.length - delta.length..-1]
                    yield(remaining) if remaining.present?
                    break
                  else
                    yield(delta)
                  end
                end
              rescue JSON::ParserError
                # Skip malformed chunks
                next
              end
            end
          end
        else
          # Fall back to non-streaming on error
          response_data = make_request(messages, stream: false)
          content = response_data.dig("choices", 0, "message", "content") || ""
          yield(truncate_response(content))
        end
      end
    rescue => e
      # Fall back to non-streaming on any error
      response_data = make_request(messages, stream: false)
      content = response_data.dig("choices", 0, "message", "content") || ""
      yield(truncate_response(content))
    end

    truncate_response(accumulated_content)
  end

  def handle_api_error(response, messages, retry_count)
    Rails.logger.error "OpenAI API error: #{response.code} - #{response.body}"

    if retry_count < 1
      Rails.logger.info "Retrying OpenAI request (attempt #{retry_count + 1})"
      sleep(1) # Brief delay before retry
      return make_request(messages, stream: false, retry_count: retry_count + 1)
    end

    raise OpenAIError.new("API error after retry: #{response.code}")
  end

  def handle_network_error(error, messages, retry_count)
    Rails.logger.error "OpenAI network error: #{error.message}"

    if retry_count < 1
      Rails.logger.info "Retrying OpenAI request after network error (attempt #{retry_count + 1})"
      sleep(2) # Longer delay for network issues
      return make_request(messages, stream: false, retry_count: retry_count + 1)
    end

    raise OpenAIError.new("Network error after retry: #{error.message}")
  end

  def handle_parse_error(error, messages, retry_count)
    Rails.logger.error "OpenAI parse error: #{error.message}"

    if retry_count < 1
      Rails.logger.info "Retrying OpenAI request after parse error (attempt #{retry_count + 1})"
      return make_request(messages, stream: false, retry_count: retry_count + 1)
    end

    raise OpenAIError.new("Parse error after retry: #{error.message}")
  end

  def truncate_response(content)
    return content if content.length <= MAX_RESPONSE_LENGTH

    # Try to truncate at sentence boundary
    truncated = content[0, MAX_RESPONSE_LENGTH]
    last_sentence_end = [ truncated.rindex("。"), truncated.rindex("？"), truncated.rindex("！") ].compact.max

    if last_sentence_end && last_sentence_end > MAX_RESPONSE_LENGTH * 0.7
      truncated = truncated[0, last_sentence_end + 1]
    end

    truncated
  end

      class OpenAIError < StandardError; end
    end
  end
end
