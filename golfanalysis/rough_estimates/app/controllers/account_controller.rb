class AccountController < ApplicationController
  def show
  end

  def update
    if current_user.update(account_params)
      redirect_to account_path, notice: "Saved."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def regenerate_api_key
    current_user.regenerate_api_key
    redirect_to account_path, notice: "Generated a new API key. Update anywhere the old one was used."
  end

  private

  def account_params
    params.require(:user).permit(:name, :player_name)
  end
end
