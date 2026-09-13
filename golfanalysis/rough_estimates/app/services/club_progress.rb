# Per-club, per-session percentile series across a user's TrackMan history —
# the same data script/plot_progress.rb charts, ported to read from Shot
# records instead of CSV files. The web Progress page now uses the richer
# per-shot Analysis dashboard instead (see AnalysisData), but this remains
# the lighter-weight aggregate the JSON API (GET /api/v1/progress) returns.
module ClubProgress
  Stats = TrackmanReport::Stats

  CLUB_ORDER = %w[
    Driver 2Wood 3Wood 4Wood 5Wood 7Wood
    2Hybrid 3Hybrid 4Hybrid 5Hybrid
    1Iron 2Iron 3Iron 4Iron 5Iron 6Iron 7Iron 8Iron 9Iron
    PitchingWedge GapWedge SandWedge LobWedge Putter
  ].freeze

  # Each chart plotted per club, in display order. `method` is the Shot
  # column/method; `abs` takes the absolute value first (for side miss);
  # `unit`/`decimals` control display formatting. `range: [lo, hi]` makes it
  # a "% of shots in range" chart (a single value per session) instead of a
  # P25/P50/P75 percentile chart.
  METRICS = {
    distance: { method: :total, label: "Total Distance", unit: " yd", decimals: 0 },
    miss: { method: :total_side, label: "Absolute Side Miss", unit: " yd", decimals: 0, abs: true },
    smash: { method: :smash_factor, label: "Smash Factor", unit: "", decimals: 2 },
    face_to_path: { method: :face_to_path, label: "Face to Path", unit: "°", decimals: 1 },
    path: { method: :club_path, label: "Club Path", unit: "°", decimals: 1 },
    f2p_in_range: { method: :face_to_path, label: "Good Face to Path", unit: "%", decimals: 0, range: [-3, 1] },
    path_in_range: { method: :club_path, label: "Good Path", unit: "%", decimals: 0, range: [-2, 2] }
  }.freeze

  def self.club_sort_key(club)
    idx = CLUB_ORDER.index(club)
    idx ? [0, idx] : [1, club]
  end

  # trackman_sessions: an association/relation of TrackmanSession, scoped to
  # one user. Returns { "Driver" => [ { report_id:, date:, shots:, distance:
  # {p25,p50,p75}, ... }, ... ], ... }, clubs in CLUB_ORDER, sessions
  # chronological within each club.
  def self.build(trackman_sessions)
    by_club = Hash.new { |h, k| h[k] = [] }

    trackman_sessions.includes(:shots).chronological.each do |session|
      session.shots.group_by(&:club).each do |club, club_shots|
        next if club.blank?

        entry = {
          report_id: session.report_id,
          date: session.session_date,
          shots: club_shots.size
        }.merge(percentiles_for(club_shots))

        by_club[club] << entry
      end
    end

    by_club
      .sort_by { |club, _| club_sort_key(club) }
      .to_h
      .transform_values { |entries| entries.sort_by { |e| [e[:date].to_s, e[:report_id]] } }
  end

  def self.percentiles_for(club_shots)
    METRICS.each_with_object({}) do |(key, cfg), out|
      vals = club_shots.filter_map(&cfg[:method])
      vals = vals.map(&:abs) if cfg[:abs]

      out[key] = if cfg[:range]
                   { p50: Stats.pct_in_range(vals, *cfg[:range]) }
                 else
                   { p25: Stats.percentile(vals, 25), p50: Stats.percentile(vals, 50), p75: Stats.percentile(vals, 75) }
                 end
    end
  end
end
