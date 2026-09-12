module Api
  module V1
    # A machine-readable index of the API, for an agent that only knows the
    # base URL and an API key to discover what it can do.
    class RootController < BaseController
      def index
        render json: {
          authenticated_as: current_user.email,
          endpoints: {
            "GET /api/v1/me" => "Current user (email, name, player_name).",
            "GET /api/v1/sessions" => "List your TrackMan sessions.",
            "POST /api/v1/sessions" => 'Add a session: {"url": "<trackman dynamic-report link>"}. Idempotent by report id.',
            "GET /api/v1/sessions/:id" => "One session's metadata + every raw shot (all TrackMan fields).",
            "GET /api/v1/sessions/:id.csv" => "The same shots as a CSV download.",
            "DELETE /api/v1/sessions/:id" => "Remove a session.",
            "GET /api/v1/summary" => "Per-club averages & dispersion for every session (mirrors the Summary page).",
            "GET /api/v1/progress" => "Per-club P25/P50/P75 series across sessions, chronological (mirrors the Progress charts)."
          }
        }
      end
    end
  end
end
