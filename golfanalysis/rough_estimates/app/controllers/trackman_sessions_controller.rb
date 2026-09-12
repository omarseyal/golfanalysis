class TrackmanSessionsController < ApplicationController
  before_action :set_trackman_session, only: %i[show destroy]

  def index
    @trackman_sessions = current_user.trackman_sessions.chronological.reverse_order
  end

  def create
    result = TrackmanIngestor.call(user: current_user, url: params[:url])

    if result.ok?
      notice = result.created? ? "Added #{result.session.session_date} at #{result.session.facility} (#{result.session.shot_count} shots)." : "Already had that session — showing it below."
      redirect_to trackman_session_path(result.session), notice: notice
    else
      redirect_to trackman_sessions_path, alert: result.error
    end
  end

  def show
    @clubs = ClubSummary.for_session(@trackman_session)
    @shots_by_club = @trackman_session.shots.group_by(&:club)

    respond_to do |format|
      format.html
      format.csv do
        rows = @trackman_session.shots.order(:session_shot_number).map(&:raw_row)
        io = StringIO.new
        TrackmanReport::CsvWriter.write(rows, io)
        send_data io.string, filename: "#{@trackman_session.session_date}_#{@trackman_session.report_id[0, 8]}.csv"
      end
    end
  end

  def destroy
    @trackman_session.destroy
    redirect_to trackman_sessions_path, notice: "Deleted that session."
  end

  private

  def set_trackman_session
    @trackman_session = current_user.trackman_sessions.find(params[:id])
  end
end
