class SummaryController < ApplicationController
  def index
    @trackman_sessions = current_user.trackman_sessions.includes(:shots).chronological
    @club_summaries = @trackman_sessions.index_with { |session| ClubSummary.for_session(session) }
  end
end
