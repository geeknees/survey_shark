class Analysis::Insight
  attr_reader :theme, :jtbd, :summary, :severity, :message_frequency, :evidence

  def initialize(theme:, jtbd:, summary:, severity:, message_frequency:, evidence:)
    @theme = theme
    @jtbd = jtbd
    @summary = summary
    @severity = severity
    @message_frequency = message_frequency
    @evidence = evidence
  end

  def high_severity?
    severity >= 4
  end

  def evidence_count
    evidence.length
  end
end