class InvitesController < ApplicationController
  allow_unauthenticated_access
  before_action :find_project_by_token
  before_action :check_project_availability, only: [ :show ]

  def show
    # Show consent page
  end

  def start
    # Increment responses count and redirect to attributes
    Rails.logger.info "Before increment: responses_count=#{@project.responses_count}"
    @project.increment!(:responses_count)
    Rails.logger.info "After increment: responses_count=#{@project.responses_count}"

    # Auto-close project if max responses reached
    if @project.responses_count >= @project.max_responses
      Rails.logger.info "Auto-closing project: responses_count=#{@project.responses_count}, max_responses=#{@project.max_responses}"
      @project.update!(status: "closed")
    end

    # Redirect to attributes form
    redirect_to invite_attributes_path(@invite_link.token)
  end

  def attributes
    # Show attributes form
  end

  def create_participant
    # Create participant and conversation, then redirect to chat
    @participant = @project.participants.build(participant_params)
    @participant.anon_hash = generate_anon_hash

    if @participant.save
      # Create conversation
      @conversation = @project.conversations.create!(
        participant: @participant,
        state: "intro",
        started_at: Time.current,
        ip: request.remote_ip,
        user_agent: request.user_agent || "Unknown"
      )

      # Create initial system message to trigger AI's first question
      initial_message = @conversation.messages.create!(
        role: 0, # user
        content: "[インタビュー開始]"
      )

      # Start the interview with the initial message
      StreamAssistantResponseJob.perform_later(@conversation.id, initial_message.id)

      # Redirect to chat page
      redirect_to conversation_path(@conversation)
    else
      render :attributes, status: :unprocessable_content
    end
  end

  private

  def find_project_by_token
    @invite_link = InviteLink.find_by!(token: params[:token])
    @project = @invite_link.project
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

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

  def render_project_not_available(message)
    render "not_available", locals: { message: message }
  end

  def render_not_found
    render "not_found", status: :not_found
  end

  def participant_params
    permitted = params.require(:participant).permit(:age, custom_attributes: {})

    # Clean up custom attributes - remove empty values
    if permitted[:custom_attributes]
      permitted[:custom_attributes] = permitted[:custom_attributes].reject { |k, v| v.blank? }
    end

    permitted
  end

  def generate_anon_hash
    # Generate a simple anonymous hash based on timestamp and random data
    Digest::SHA256.hexdigest("#{Time.current.to_f}-#{SecureRandom.hex(8)}")[0..15]
  end
end
