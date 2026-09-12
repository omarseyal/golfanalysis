module Api
  module V1
    class TrackmanSessionsController < BaseController
      before_action :set_trackman_session, only: %i[show destroy]

      def index
        sessions = current_user.trackman_sessions.chronological.reverse_order
        render json: sessions.map { |s| session_json(s) }
      end

      def create
        result = TrackmanIngestor.call(user: current_user, url: params[:url])

        if result.ok?
          render json: session_json(result.session), status: (result.created? ? :created : :ok)
        else
          render json: { error: result.error }, status: :unprocessable_entity
        end
      end

      # Always JSON unless ".csv" is explicitly requested — agents don't
      # always send an Accept header, so format negotiation stays keyed off
      # the URL, not content negotiation.
      def show
        if params[:format] == "csv"
          rows = @trackman_session.shots.order(:session_shot_number).map(&:raw_row)
          io = StringIO.new
          TrackmanReport::CsvWriter.write(rows, io)
          send_data io.string, filename: "#{@trackman_session.session_date}_#{@trackman_session.report_id[0, 8]}.csv"
        else
          render json: session_json(@trackman_session).merge(
            shots: @trackman_session.shots.order(:session_shot_number).map(&:raw_row)
          )
        end
      end

      def destroy
        @trackman_session.destroy
        head :no_content
      end

      private

      def set_trackman_session
        @trackman_session = current_user.trackman_sessions.find(params[:id])
      end

      def session_json(session)
        {
          id: session.id,
          report_id: session.report_id,
          date: session.session_date,
          facility: session.facility,
          bay: session.bay,
          player_name: session.player_name,
          shot_count: session.shot_count,
          clubs: session.clubs,
          source_url: session.source_url,
          fetched_at: session.fetched_at
        }
      end
    end
  end
end
