module Api
  module V1
    class ProgressController < BaseController
      def index
        render json: ClubProgress.build(current_user.trackman_sessions)
      end
    end
  end
end
