module Api
  module V1
    class MeController < BaseController
      def show
        render json: current_user.as_json(only: %i[id email name player_name created_at])
      end
    end
  end
end
