# Token-authenticated JSON API for agents/scripts. Send the API token
# (config/credentials.yml.enc's `api_token`) as `Authorization: Bearer <token>`.
module Api
  module V1
    class BaseController < ActionController::Base
      skip_forgery_protection

      before_action :authenticate_with_token!

      private

      def authenticate_with_token!
        provided = request.authorization&.split(" ", 2)&.last
        expected = Rails.application.credentials.api_token

        authorized = expected.present? && provided.present? &&
          ActiveSupport::SecurityUtils.secure_compare(provided, expected)

        render json: { error: "Missing or invalid API token. Send it as `Authorization: Bearer <token>`." }, status: :unauthorized unless authorized
      end
    end
  end
end
