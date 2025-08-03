class ProjectsController < ApplicationController
  before_action :require_authentication
  before_action :set_project, only: [ :show, :edit, :update, :destroy, :generate_invite_link ]

  def index
    @projects = Project.all.order(:name)
  end

  def show
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)

    if @project.save
      redirect_to @project, notice: "Project was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @project.update(project_params)
      redirect_to @project, notice: "Project was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @project.destroy
    redirect_to projects_url, notice: "Project was successfully deleted."
  end

  def generate_invite_link
    @invite_link = @project.invite_links.first_or_create!
    redirect_to @project, notice: "Invite link generated successfully."
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    permitted = params.require(:project).permit(
      :name, :goal, :tone, :status, :max_responses, :must_ask_text, :never_ask_text,
      limits: [ :max_turns, :max_deep ]
    )

    # Convert text fields to arrays
    if permitted[:must_ask_text].present?
      permitted[:must_ask] = permitted[:must_ask_text].split("\n").map(&:strip).reject(&:blank?)
      permitted.delete(:must_ask_text)
    end

    if permitted[:never_ask_text].present?
      permitted[:never_ask] = permitted[:never_ask_text].split("\n").map(&:strip).reject(&:blank?)
      permitted.delete(:never_ask_text)
    end

    permitted
  end
end
