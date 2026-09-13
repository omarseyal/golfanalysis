module Api
  module V1
    # The same compact per-shot dataset the Analysis dashboard (GET /progress)
    # renders client-side, as JSON: { dates:, clubs:, cols:, rows: } where
    # each row is [date_index, club_index, carry, total, side, smash, f2p,
    # path, face, clubSpeed]. All measurements are in real-world units
    # (yards, mph, degrees) -- see TrackmanReport::Units.
    class ShotsController < BaseController
      def index
        render json: AnalysisData.for_user(current_user)
      end
    end
  end
end
