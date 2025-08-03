class PII::DetectionResult
  attr_reader :original_text, :masked_content, :detected_items

  def initialize(original_text, pii_detected, masked_content, detected_items)
    @original_text = original_text
    @pii_detected = pii_detected
    @masked_content = masked_content
    @detected_items = detected_items
  end

  def pii_detected?
    @pii_detected
  end

  def summary
    if pii_detected?
      "PII detected: #{detected_items.join(', ')}"
    else
      "No PII detected"
    end
  end
end