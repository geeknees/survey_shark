class InvitesController < ApplicationController
  allow_unauthenticated_access
  before_action :find_project_by_token
  before_action :check_project_availability, only: [:show]

  def show
    # Show consent page
  end

  def start
    # Increment responses count and redirect to attributes
    @project.increment!(:responses_count)
    
    # Auto-close project if max responses reached
    if @project.responses_count >= @project.max_responses
      @project.update!(status: 'closed')
    end
    
    # For now, redirect to a placeholder (will be attributes page in next prompt)
    redirect_to invite_path(@invite_link.token), notice: "Started! (Attributes page coming in next prompt)"
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
      @project.update!(status: 'closed') unless @project.closed?
      render_project_not_available("募集は終了しました。ご協力ありがとうございました。")
    end
  end

  def render_project_not_available(message)
    render 'not_available', locals: { message: message }
  end

  def render_not_found
    render 'not_found', status: :not_found
  end
end