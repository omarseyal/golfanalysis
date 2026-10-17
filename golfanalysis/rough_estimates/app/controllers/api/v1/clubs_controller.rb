module Api
  module V1
    # Read-only club stats -- the numbers behind the Overview and each club's
    # page (see ClubStats) -- for the game. Unlike the rest of the API it
    # also takes the user's read-only game token, and it's open to any
    # origin (CORS), so a browser game can call it directly. The token can
    # go in `Authorization: Bearer <token>` or, to skip the CORS preflight,
    # `?token=<token>`.
    class ClubsController < BaseController
      skip_before_action :authenticate_with_token!
      before_action :allow_cross_origin
      before_action :authenticate_reader!, except: :preflight

      # GET /api/v1/clubs?window=14|30|all
      def index
        render json: ClubStats.new(current_user).overview(window: params[:window] || "14")
      end

      # GET /api/v1/clubs/:club
      def show
        stats = ClubStats.new(current_user)
        if (data = stats.club(params[:club]))
          render json: data
        else
          render json: { error: "No shots with club #{params[:club]}.", clubs: stats.clubs }, status: :not_found
        end
      end

      # OPTIONS -- the CORS preflight for a request with an Authorization header.
      def preflight
        head :no_content
      end

      private

      def allow_cross_origin
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "Authorization"
        response.headers["Access-Control-Max-Age"] = "86400"
      end

      def authenticate_reader!
        token = request.authorization&.split(" ", 2)&.last.presence || params[:token].presence
        @current_user = token && (User.find_by(game_token: token) || User.find_by(api_key: token))
        return if @current_user

        render json: { error: "Missing or invalid token. Send your game token (from /account) as `Authorization: Bearer <token>` or `?token=<token>`." },
               status: :unauthorized
      end
    end
  end
end
