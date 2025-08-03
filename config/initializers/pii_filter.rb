# Filter PII from logs
Rails.application.configure do
  # Add parameter filtering for PII-related fields
  config.filter_parameters += [
    :content,           # Message content may contain PII
    :original_content,  # Original unmasked content
    :attributes,        # Participant attributes may contain PII
    :user_agent,        # May contain identifying information
    :ip                 # IP addresses are PII
  ]

  # Custom log filter to mask PII in message content
  config.log_tags = [
    lambda do |request|
      # Don't log raw message content in production
      if Rails.env.production? && request.params[:content].present?
        "content=[FILTERED]"
      else
        nil
      end
    end
  ]
end

# Override Rails logger to filter PII from message logs
class PIILogFilter
  def self.filter_message_content(message)
    # If message has been processed for PII and contains PII, log only masked version
    if message.is_a?(Message) && message.meta&.dig("pii_detected")
      message.content # Already masked
    elsif message.is_a?(String)
      # Simple filtering for string content
      message.gsub(/田中|佐藤|山田|鈴木|高橋/, "[氏名]")
             .gsub(/\d{2,4}-\d{2,4}-\d{4}/, "[電話番号]")
             .gsub(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/, "[メールアドレス]")
    else
      message
    end
  end
end

# Monkey patch ActiveRecord logging to filter PII
if Rails.env.production?
  ActiveRecord::Base.logger = ActiveSupport::Logger.new(Rails.root.join("log", "production.log"))
  ActiveRecord::Base.logger.formatter = proc do |severity, datetime, progname, msg|
    filtered_msg = if msg.include?('INSERT INTO "messages"') || msg.include?('UPDATE "messages"')
      msg.gsub(/'([^']*田中[^']*|[^']*佐藤[^']*|[^']*\d{2,4}-\d{2,4}-\d{4}[^']*)'/, "'[FILTERED_PII]'")
    else
      msg
    end
    "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} #{severity} #{filtered_msg}\n"
  end
end
