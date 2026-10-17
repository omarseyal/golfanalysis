# The numbers the Analysis dashboard shows -- the Overview (gapping + "By
# club" cards) and each club's drill-down (stat tiles, stories, trend,
# "is it real?", dispersion, session log) -- computed server-side for the
# club API (GET /api/v1/clubs, /api/v1/clubs/:club).
#
# This is a port of the dashboard's own client-side JS in
# app/views/analysis/index.html.erb (quant, sd, blockStat, diffSig,
# improve, story, rollingSVG, noiseSVG, ellipse, gappingSVG), so the API and
# the pages agree. Change one, change the other.
#
#   ClubStats.new(user).overview(window: "14")
#   ClubStats.new(user).club("7Iron")
class ClubStats
  UNLOCK_SHOTS = 60 # the dashboard's drill-down floor

  # key => shot column, display, and which way is better. dir 1: higher is
  # better, -1: lower is better, 0: closer to `target` is better.
  METRICS = {
    "total" => { col: :total, label: "Total distance", unit: "yd", dec: 1, dir: 1 },
    "carry" => { col: :carry, label: "Carry", unit: "yd", dec: 1, dir: 1 },
    "aside" => { col: :side, abs: true, label: "Side miss (absolute)", unit: "yd", dec: 1, dir: -1 },
    "side" => { col: :side, label: "Side (+right)", unit: "yd", dec: 1, dir: 0, target: 0 },
    "smash" => { col: :smash, label: "Smash factor", unit: "", dec: 3, dir: 1 },
    "f2p" => { col: :f2p, label: "Face-to-path", unit: "deg", dec: 2, dir: 0, target: -1 },
    "path" => { col: :path, label: "Club path", unit: "deg", dec: 2, dir: 0, target: 0 }
  }.freeze
  CARD_KEYS = %w[carry total aside smash path f2p].freeze
  TREND_KEYS = %w[total carry aside side smash f2p path].freeze

  LOFT_ORDER = %w[Driver 2Wood 3Wood 4Wood 5Wood 7Wood 2Hybrid 3Hybrid 4Hybrid 5Hybrid
    1Iron 2Iron 3Iron 4Iron 5Iron 6Iron 7Iron 8Iron 9Iron
    PitchingWedge GapWedge SandWedge LobWedge Putter].freeze

  WINDOWS = { "14" => 14, "30" => 30, "all" => nil }.freeze
  ROLLING_WINDOW = 50 # shots, the dashboard's default

  Shot = Struct.new(:date, :club, :carry, :total, :side, :smash, :f2p, :path, keyword_init: true)

  def initialize(user)
    @user = user
    data = AnalysisData.for_user(user)
    dates = data[:dates].map { |d| Date.iso8601(d) }
    @shots = data[:rows].map do |(di, ci, carry, total, side, smash, f2p, path)|
      Shot.new(date: dates[di], club: data[:clubs][ci], carry: carry, total: total, side: side, smash: smash, f2p: f2p, path: path)
    end
    @by_club = @shots.group_by(&:club)
  end

  def clubs
    @by_club.keys.sort_by { |c| [ LOFT_ORDER.index(c) || -1, c ] }
  end

  # ---- Overview ----

  def overview(window: "14")
    window = WINDOWS.key?(window.to_s) ? window.to_s : "14"
    dates = @shots.map(&:date).uniq.sort
    gapping = %w[total carry].to_h { |key| [ key, gapping(key, WINDOWS[window]) ] }

    {
      player: player,
      metrics: metric_info,
      shots: @shots.size,
      sessions: dates.size,
      first_date: dates.first, last_date: dates.last,
      window: { requested: window, days: WINDOWS[window], applied: gapping["total"][:windowed] },
      clubs: clubs.map { |c| club_card(c, gapping) },
      overlaps: gapping.transform_values { |g| g[:overlaps] }
    }
  end

  # ---- One club's drill-down ----

  def club(name)
    rows = @by_club[name]
    return nil unless rows

    sess = sessions_of(rows, 3)
    {
      player: player,
      club: name,
      unlocked: rows.size >= UNLOCK_SHOTS,
      shots_to_unlock: [ UNLOCK_SHOTS - rows.size, 0 ].max,
      shots: rows.size,
      sessions: sess.size,
      first_date: rows.map(&:date).min, last_date: rows.map(&:date).max,
      last_session_shots: sess.last && sess.last[:rows].size,
      metrics: metric_info,
      stats: CARD_KEYS.to_h { |k| [ k, card_stat(sess, METRICS[k]) ] },
      distribution: METRICS.keys.to_h { |k| [ k, distribution(vals(rows, METRICS[k]), METRICS[k]) ] },
      stories: TREND_KEYS.to_h { |k| [ k, story(sess, METRICS[k]) ] },
      trend: TREND_KEYS.to_h { |k| [ k, rolling(rows, METRICS[k]) ] },
      is_it_real: TREND_KEYS.to_h { |k| [ k, noise(rows, METRICS[k]) ] },
      dispersion: dispersion(rows),
      session_log: sess.map { |s| session_row(s) }
    }
  end

  private

  def player
    { name: @user.player_name.presence || @user.name.presence }
  end

  def metric_info
    METRICS.transform_values do |m|
      { label: m[:label], unit: m[:unit], better: { 1 => "higher", -1 => "lower", 0 => "closer to #{m[:target]}" }[m[:dir]] }
    end
  end

  # ---- stats helpers (match the dashboard's JS) ----

  def mean(a) = a.empty? ? nil : a.sum.to_f / a.size

  def sd(a)
    return 0.0 if a.size < 2
    m = mean(a)
    Math.sqrt(a.sum { |x| (x - m)**2 } / (a.size - 1))
  end

  # Linear-interpolated percentile, p in 0..1.
  def quant(a, p)
    return nil if a.empty?
    s = a.sort
    i = (s.size - 1) * p
    lo, hi = i.floor, i.ceil
    lo == hi ? s[lo] : s[lo] + (s[hi] - s[lo]) * (i - lo)
  end

  def vals(rows, m)
    v = rows.filter_map { |r| r[m[:col]] }
    m[:abs] ? v.map(&:abs) : v
  end

  # Sessions (by date) with at least min_n shots, oldest first.
  def sessions_of(rows, min_n)
    rows.group_by(&:date).select { |_, v| v.size >= min_n }.sort_by(&:first)
      .map { |date, v| { date: date, rows: v } }
  end

  def improve(m, cur, prev)
    case m[:dir]
    when 1 then cur - prev
    when -1 then prev - cur
    else (prev - m[:target]).abs - (cur - m[:target]).abs
    end
  end

  def block_stat(sessions, m)
    v = sessions.flat_map { |s| vals(s[:rows], m) }
    { mu: mean(v), sd: sd(v), se: sd(v) / Math.sqrt([ 1, v.size ].max), n: v.size }
  end

  def diff_sig(a, b)
    (a[:mu] - b[:mu]).abs > 1.96 * Math.sqrt(a[:se]**2 + b[:se]**2)
  end

  def r(v, m) = v&.round(m[:dec])

  # ---- Overview pieces ----

  # Distance distribution per club for the gapping ridgeline. A club with
  # nothing in the window falls back to all its shots, flagged stale; if
  # every club would be stale the whole thing falls back to all-time.
  def gapping(key, window_days)
    m = METRICS[key]
    last_day = @shots.map(&:date).max
    cutoff = window_days && last_day ? last_day - window_days + 1 : nil

    series = ->(cut) {
      clubs.filter_map do |c|
        all = @by_club[c]
        fresh = cut ? all.select { |s| s.date >= cut } : all
        stale = cut && fresh.empty? && all.any?
        v = (stale ? all : fresh).filter_map { |s| s[m[:col]] }
        next if v.empty?
        { club: c, v: v, stale: !!stale, last_hit: (all.map(&:date).max if stale) }
      end
    }

    ser = series.(cutoff)
    windowed = !cutoff.nil?
    if cutoff && ser.all? { |s| s[:stale] }
      ser = series.(nil)
      windowed = false
    end

    by_club = ser.to_h do |s|
      [ s[:club], {
        shots: s[:v].size, median: r(quant(s[:v], 0.5), m), p10: r(quant(s[:v], 0.1), m), p25: r(quant(s[:v], 0.25), m),
        p75: r(quant(s[:v], 0.75), m), p90: r(quant(s[:v], 0.9), m), sd: r(sd(s[:v]), m),
        stale: s[:stale], last_hit: s[:last_hit]
      } ]
    end

    # P90 of the shorter club against P10 of the longer, in bag order.
    overlaps = ser.each_cons(2).filter_map do |longer, shorter|
      lap = quant(shorter[:v], 0.9) - quant(longer[:v], 0.1)
      { shorter: shorter[:club], longer: longer[:club], yards: lap.round(1) } if lap.positive?
    end

    { windowed: windowed, by_club: by_club, overlaps: overlaps }
  end

  def club_card(c, gapping)
    rows = @by_club[c]
    sess = sessions_of(rows, 3)
    card = {
      club: c,
      shots: rows.size,
      sessions: sess.size,
      last_date: rows.map(&:date).max,
      unlocked: rows.size >= UNLOCK_SHOTS,
      gapping: gapping.transform_values { |g| g[:by_club][c] }
    }
    if card[:unlocked]
      card[:stats] = CARD_KEYS.to_h { |k| [ k, card_stat(sess, METRICS[k]) ] }
    else
      card[:shots_to_unlock] = UNLOCK_SHOTS - rows.size
      card[:median_carry_so_far] = r(quant(vals(rows, METRICS["carry"]), 0.5), METRICS["carry"])
    end
    card
  end

  # A stat tile / card metric: the latest session's mean against the three
  # sessions before it, and whether the move clears sampling noise.
  def card_stat(sess, m)
    return nil if sess.empty?
    cur = block_stat(sess.last(1), m)
    base = block_stat(sess[[ sess.size - 4, 0 ].max...(sess.size - 1)] || [], m)
    out = { last_session: r(cur[:mu], m), baseline: r(base[:mu], m),
            session_medians: sess.map { |s| r(quant(vals(s[:rows], m), 0.5), m) } }
    return out.merge(change: nil, significant: false, trend: nil) if base[:n].zero? || cur[:n].zero?

    sig = diff_sig(cur, base)
    imp = improve(m, cur[:mu], base[:mu])
    out.merge(change: r(cur[:mu] - base[:mu], m), significant: sig, trend: sig ? (imp.positive? ? "better" : "worse") : "flat")
  end

  # ---- Drill-down pieces ----

  def distribution(v, m)
    return nil if v.empty?
    { shots: v.size, mean: r(mean(v), m), sd: r(sd(v), m),
      p10: r(quant(v, 0.1), m), p25: r(quant(v, 0.25), m), median: r(quant(v, 0.5), m),
      p75: r(quant(v, 0.75), m), p90: r(quant(v, 0.9), m) }
  end

  # The story line above each chart: first k sessions vs last k, and last k
  # vs the k before them.
  def story(sess, m)
    n = sess.size
    return nil if n < 4
    k = [ 1, [ 3, n / 3 ].min ].max
    early = block_stat(sess.first(k), m)
    late = block_stat(sess.last(k), m)
    mid = block_stat(sess[(n - 2 * k)...(n - k)], m)
    sig_all = diff_sig(late, early)
    sig_recent = diff_sig(late, mid)
    imp_all = improve(m, late[:mu], early[:mu])
    imp_recent = improve(m, late[:mu], mid[:mu])

    spread = if early[:sd].positive? && late[:sd].positive?
      pc = (late[:sd] / early[:sd] - 1) * 100
      pc.abs < 8 ? "unchanged" : (pc.negative? ? "tightened" : "widened")
    end

    {
      verdict: sig_all ? (imp_all.positive? ? "better" : "worse") : "flat",
      sessions: n, block_size: k,
      early: { mean: r(early[:mu], m), sd: r(early[:sd], m) },
      late: { mean: r(late[:mu], m), sd: r(late[:sd], m) },
      still_moving: sig_recent,
      recent_direction: sig_recent ? (imp_recent.positive? ? "better" : "worse") : nil,
      spread: spread
    }
  end

  # Centred rolling mean over shots in date order, and its rate of change
  # per month -- averaged over the first and most recent quarter.
  def rolling(rows, m, win = ROLLING_WINDOW)
    pts = rows.each_with_index.filter_map { |s, i| [ s.date.jd, s[m[:col]], i ] unless s[m[:col]].nil? }
      .sort_by { |t, _, i| [ t, i ] }
      .map { |t, v, _| [ t, m[:abs] ? v.abs : v ] }
    return nil if pts.size < 30

    w = [ 8, [ win, pts.size / 3 ].min ].max
    half = w / 2
    slopes = (half...(pts.size - half)).map do |i|
      span = pts[(i - half)..(i + half)]
      tt = span.map(&:first)
      vv = span.map(&:last)
      mt, mu = mean(tt), mean(vv)
      num = tt.zip(vv).sum { |t, v| (t - mt) * (v - mu) }
      den = tt.sum { |t| (t - mt)**2 }
      den > 1e-6 ? num / den * 30.44 : 0.0
    end
    q = [ 3, (slopes.size * 0.25).floor ].max
    { window_shots: w, shots: pts.size,
      early_change_per_month: mean(slopes.first(q))&.round(m[:dec] + 1),
      recent_change_per_month: mean(slopes.last(q))&.round(m[:dec] + 1) }
  end

  # Session means with 95% intervals against a five-session trailing mean.
  def noise(rows, m)
    sess = sessions_of(rows, 2).map do |s|
      v = vals(s[:rows], m)
      { date: s[:date], n: v.size, mu: mean(v), se: v.empty? ? 0 : sd(v) / Math.sqrt(v.size) }
    end.reject { |s| s[:mu].nil? }
    return nil if sess.size < 4

    out = sess.each_with_index.map do |s, i|
      trail = mean(sess[[ 0, i - 4 ].max..i].map { |x| x[:mu] })
      sig = (s[:mu] - 1.96 * s[:se] > trail) || (s[:mu] + 1.96 * s[:se] < trail)
      { date: s[:date], shots: s[:n], mean: r(s[:mu], m), ci95: r(1.96 * s[:se], m), trailing_mean: r(trail, m),
        verdict: sig ? (improve(m, s[:mu], trail).positive? ? "better" : "worse") : "noise" }
    end
    { sessions: out.size, beyond_noise: out.count { |s| s[:verdict] != "noise" }, by_session: out }
  end

  # The 68% ellipse of (total, side) -- the "Session by session" rings.
  # major/minor are full axis lengths in yards; angle is the major axis
  # from the downrange line, positive toward the right.
  def ellipse(rows, k = 1.5136)
    pts = rows.filter_map { |s| [ s.total, s.side ] if s.total && s.side }
    n = pts.size
    return nil if n < 3
    mx = mean(pts.map(&:first))
    my = mean(pts.map(&:last))
    a = pts.sum { |x, _| (x - mx)**2 } / (n - 1)
    b = pts.sum { |x, y| (x - mx) * (y - my) } / (n - 1)
    c = pts.sum { |_, y| (y - my)**2 } / (n - 1)
    tr = a + c
    det = a * c - b * b
    s = Math.sqrt([ 0, tr * tr / 4 - det ].max)
    l1 = tr / 2 + s
    l2 = [ 1e-9, tr / 2 - s ].max
    v1 = b.abs > 1e-9 ? [ b, l1 - a ] : (a >= c ? [ 1, 0 ] : [ 0, 1 ])
    { center: { total: mx.round(1), side: my.round(1) },
      major_yd: (2 * k * Math.sqrt([ l1, 1e-9 ].max)).round(1), minor_yd: (2 * k * Math.sqrt(l2)).round(1),
      angle_deg: (Math.atan2(v1[1], v1[0]) * 180 / Math::PI).round(1) }
  end

  def dispersion(rows)
    { all_shots: ellipse(rows),
      by_session: sessions_of(rows, 5).map { |s| { date: s[:date], shots: s[:rows].size, ellipse: ellipse(s[:rows]) } } }
  end

  # One row of the Session log table: per-session medians.
  def session_row(s)
    med = ->(k) { r(quant(vals(s[:rows], METRICS[k]), 0.5), METRICS[k]) }
    { date: s[:date], shots: s[:rows].size,
      total: med.("total"), total_sd: r(sd(vals(s[:rows], METRICS["total"])), METRICS["total"]),
      carry: med.("carry"), side: med.("side"), aside: med.("aside"),
      smash: med.("smash"), f2p: med.("f2p"), path: med.("path") }
  end
end
