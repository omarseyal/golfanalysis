# Token-authenticated JSON API for agents/scripts. Send the user's API key
# (shown on their /account page) as `Authorization: Bearer <api_key>`.
# Deliberately separate from ApplicationController's cookie-session auth.
module Api
  module V1
    class BaseController < ActionController::Base
      skip_forgery_protection

      before_action :authenticate_with_token!

      rescue_from ActiveRecord::RecordNotFound do
        render json: { error: "Not found." }, status: :not_found
      end

      private

      def authenticate_with_token!
        token = request.authorization&.split(" ", 2)&.last

        @current_user = token.present? && User.find_by(api_key: token)
        render json: { error: "Missing or invalid API key. Send it as `Authorization: Bearer <api_key>`." }, status: :unauthorized unless @current_user
      end

      attr_reader :current_user
    end
  end
end
