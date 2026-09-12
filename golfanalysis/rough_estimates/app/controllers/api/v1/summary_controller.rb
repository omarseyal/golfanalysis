module Api
  module V1
    class SummaryController < BaseController
      def index
        sessions = current_user.trackman_sessions.includes(:shots).chronological

        render json: sessions.map { |session|
          {
            id: session.id,
            report_id: session.report_id,
            date: session.session_date,
            facility: session.facility,
            bay: session.bay,
            total_shots: session.shot_count,
            clubs: ClubSummary.for_session(session)
          }
        }
      end
    end
  end
end
