class ThankYousController < ApplicationController
  include ProjectAccess

  allow_unauthenticated_access
  before_action :set_project

  def show
    # Show thank you page after conversation completion
  end

  def restart
    # Create a new conversation for the same project
    if @project.active? && !project_at_limit?
      # Increment responses count
      increment_project_responses!

      # Create new participant and conversation
      participant = @project.participants.create!(
        anon_hash: generate_anon_hash,
        age: session[:participant_age],
        custom_attributes: session[:participant_attributes] || {}
      )

      conversation = @project.conversations.create!(
        participant: participant,
        state: "intro",
        started_at: Time.current,
        ip: request.remote_ip,
        user_agent: request.user_agent
      )

      # Clear session data
      session[:participant_age] = nil
      session[:participant_attributes] = nil

      redirect_to conversation_path(conversation)
    else
      # Project is closed or at limit
      redirect_to invite_path(@project.invite_links.first.token),
                  alert: "申し訳ございませんが、このプロジェクトは募集を終了しました。"
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end
end
