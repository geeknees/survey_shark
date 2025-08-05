module ProjectAccess
  extend ActiveSupport::Concern

  private

  # Generate anonymous hash for participant identification
  def generate_anon_hash
    Digest::SHA256.hexdigest("#{Time.current.to_f}-#{SecureRandom.hex(8)}")[0..15]
  end

  # Find project by invite token
  def find_project_by_token
    @invite_link = InviteLink.find_by!(token: params[:token])
    @project = @invite_link.project
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  # Check if project is available for participation
  def check_project_availability
    if @project.draft?
      render_project_not_available("This project is not yet active.")
    elsif @project.closed?
      render_project_not_available("募集は終了しました。ご協力ありがとうございました。")
    elsif @project.responses_count >= @project.max_responses
      @project.update!(status: "closed") unless @project.closed?
      render_project_not_available("募集は終了しました。ご協力ありがとうございました。")
    end
  end

  # Check if project has reached response limit
  def project_at_limit?
    @project.responses_count >= @project.max_responses
  end

  # Increment project response count and auto-close if needed
  def increment_project_responses!
    Rails.logger.info "Before increment: responses_count=#{@project.responses_count}"
    @project.increment!(:responses_count)
    Rails.logger.info "After increment: responses_count=#{@project.responses_count}"

    # Auto-close project if max responses reached
    if @project.responses_count >= @project.max_responses
      Rails.logger.info "Auto-closing project: responses_count=#{@project.responses_count}, max_responses=#{@project.max_responses}"
      @project.update!(status: "closed")
    end
  end

  # Render project not available page
  def render_project_not_available(message)
    render "not_available", locals: { message: message }
  end

  # Render not found page
  def render_not_found
    render "not_found", status: :not_found
  end
end
