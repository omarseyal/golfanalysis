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
            "GET /api/v1/summary" => "Per-club averages & dispersion for every session.",
            "GET /api/v1/progress" => "Per-club P25/P50/P75 series across sessions, chronological (lighter aggregate).",
            "GET /api/v1/shots" => "Every shot, per-club and per-session, real-world units (yd/mph/deg) -- mirrors the Overview dashboard's own dataset.",
            "GET /api/v1/clubs?window=14|30|all" => "The Overview's numbers: gapping per club (median/P10-P90/sd, in the window), overlaps, and each club's card stats vs its last 3 sessions. Also takes the read-only game token.",
            "GET /api/v1/clubs/:club" => "One club's page: stat tiles, distributions, stories, trend, 'is it real?', dispersion ellipses, session log. Also takes the read-only game token."
          }
        }
      end
    end
  end
end
