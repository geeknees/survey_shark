class InvitesController < ApplicationController
  include ProjectAccess

  allow_unauthenticated_access
  before_action :find_project_by_token
  before_action :check_project_availability, only: [ :show ]

  def show
    # Show consent page
  end

  def start
    # Increment responses count and redirect to attributes
    increment_project_responses!

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

  def participant_params
    permitted = params.require(:participant).permit(:age, custom_attributes: {})

    # Clean up custom attributes - remove empty values
    if permitted[:custom_attributes]
      permitted[:custom_attributes] = permitted[:custom_attributes].reject { |k, v| v.blank? }
    end

    permitted
  end
end
