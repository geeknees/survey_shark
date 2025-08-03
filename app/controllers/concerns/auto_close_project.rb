module AutoCloseProject
  extend ActiveSupport::Concern

  private

  def check_and_auto_close_project(project)
    return unless project.active?

    kpis = ProjectKpis.new(project)

    if kpis.should_auto_close?
      project.update!(status: "closed")
      Rails.logger.info "Auto-closed project #{project.id} - reached max responses limit"
    end
  end
end
