# Cookie-session auth for the web UI, plus a separate Bearer-token path
# (`authenticate_via_token!`) that API controllers use instead — see
# Api::V1::BaseController.
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :set_current_user
    helper_method :current_user, :logged_in?
  end

  def current_user
    Current.user
  end

  def logged_in?
    current_user.present?
  end

  def require_login
    return if logged_in?

    respond_to do |format|
      format.html { redirect_to login_path, alert: "Please log in first." }
      format.any { render json: { error: "Not authenticated." }, status: :unauthorized }
    end
  end

  def login(user)
    reset_session
    session[:user_id] = user.id
    Current.user = user
  end

  def logout
    reset_session
    Current.user = nil
  end

  private

  def set_current_user
    Current.user = User.find_by(id: session[:user_id]) if session[:user_id]
  end
end
