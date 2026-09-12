# Per-club averages & dispersion for one TrackmanSession's shots — the same
# numbers script/fetch_sessions.rb writes into summary.md, ported to read
# from Shot records instead of a CSV row. Used by the Summary page (one
# section per session) and by the JSON API.
module ClubSummary
  Stats = TrackmanReport::Stats

  AVG_FIELDS = {
    club_speed: "Club Speed",
    ball_speed: "Ball Speed",
    smash_factor: "Smash Factor",
    carry: "Carry",
    total: "Total"
  }.freeze

  def self.for_session(trackman_session)
    clubs = trackman_session.shots.group_by(&:club).map do |club, club_shots|
      { club: club, shots: club_shots.size }
        .merge(averages: averages(club_shots))
        .merge(dispersion: dispersion(club_shots))
    end

    clubs.sort_by { |c| -c[:shots] }
  end

  def self.averages(club_shots)
    AVG_FIELDS.each_with_object({}) do |(field, label), out|
      values = club_shots.filter_map(&field)
      out[label] = {
        mean: Stats.mean(values),
        median: Stats.median(values),
        p25: Stats.percentile(values, 25),
        p75: Stats.percentile(values, 75)
      }
    end
  end

  def self.dispersion(club_shots)
    side_vals = club_shots.filter_map(&:total_side)
    abs_side_vals = side_vals.map(&:abs)
    f2p_vals = club_shots.filter_map(&:face_to_path)
    path_vals = club_shots.filter_map(&:club_path)

    {
      side_variance: Stats.variance(side_vals),
      side_abs_avg_miss: Stats.mean(side_vals)&.abs,
      side_abs_median_miss: Stats.median(side_vals)&.abs,
      side_miss_distance_mean: Stats.mean(abs_side_vals),
      side_miss_distance_p25: Stats.percentile(abs_side_vals, 25),
      side_miss_distance_p50: Stats.percentile(abs_side_vals, 50),
      side_miss_distance_p75: Stats.percentile(abs_side_vals, 75),
      f2p_variance: Stats.variance(f2p_vals),
      f2p_avg: Stats.mean(f2p_vals),
      f2p_median: Stats.median(f2p_vals),
      f2p_pct_in_range: Stats.pct_in_range(f2p_vals, -3, 1),
      path_variance: Stats.variance(path_vals),
      path_avg: Stats.mean(path_vals),
      path_median: Stats.median(path_vals),
      path_pct_in_range: Stats.pct_in_range(path_vals, -2, 2)
    }
  end
end
