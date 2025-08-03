class AdminsController < ApplicationController
  before_action :set_admin

  def edit_password
  end

  def update_password
    if @admin.authenticate(params[:current_password])
      if @admin.update(password_params)
        redirect_to root_path, notice: "Password was successfully updated."
      else
        flash.now[:alert] = "Password confirmation doesn't match or password is too short."
        render :edit_password, status: :unprocessable_entity
      end
    else
      flash.now[:alert] = "Current password is incorrect."
      render :edit_password, status: :unprocessable_entity
    end
  end

  private

  def set_admin
    @admin = Current.session.admin
  end

  def password_params
    params.require(:admin).permit(:password, :password_confirmation)
  end
end
