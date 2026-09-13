# Builds the compact per-shot dataset the Analysis dashboard's client-side
# JS expects: dates/clubs as lookup tables, each shot a row of indices +
# numbers (matches script/plot_progress.rb's philosophy of keeping the
# payload small, just one level deeper -- per shot, not per session).
#
#   AnalysisData.for_user(current_user)
#   # => { dates: [...], clubs: [...], cols: [...], rows: [[0, 0, 92.1, ...], ...] }
module AnalysisData
  COLS = %w[date club carry total side smash f2p path face clubSpeed].freeze

  def self.for_user(user)
    records = TrackmanSession.where(user: user)
      .joins(:shots)
      .where.not(shots: { club: [nil, ""] })
      .pluck(
        :session_date, "shots.club", "shots.carry", "shots.total", "shots.total_side",
        "shots.smash_factor", "shots.face_to_path", "shots.club_path", "shots.face_angle", "shots.club_speed"
      )

    dates = records.map { |r| r[0] }.compact.uniq.sort
    date_index = dates.each_with_index.to_h
    clubs = records.map { |r| r[1] }.uniq.sort
    club_index = clubs.each_with_index.to_h

    rows = records.map do |(date, club, *measurements)|
      [date_index[date], club_index[club], *measurements]
    end

    { dates: dates.map(&:iso8601), clubs: clubs, cols: COLS, rows: rows }
  end
end
