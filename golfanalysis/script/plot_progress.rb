#!/usr/bin/env ruby
# Reads the per-session CSVs written by fetch_sessions.rb and renders a
# self-contained HTML page (no network access or JS libraries required) with
# progress charts per club: the 25th/50th/75th percentile of Total distance,
# absolute side miss (|Total Side|), Smash Factor, Face to Path, and Club
# Path, one point per session, ordered chronologically. Each chart shows the
# median as a line with the P25-P75 band shaded around it. See METRICS below
# to add or remove charts.
#
# Usage: ruby script/plot_progress.rb [sessions_dir] [output_html]

require "csv"
require "cgi"
require_relative "../lib/trackman_report"

Stats = TrackmanReport::Stats

sessions_dir = ARGV[0] || File.join(__dir__, "..", "output", "sessions")
output_html = ARGV[1] || File.join(__dir__, "..", "output", "progress.html")

CLUB_ORDER = %w[
  Driver 2Wood 3Wood 4Wood 5Wood 7Wood
  2Hybrid 3Hybrid 4Hybrid 5Hybrid
  1Iron 2Iron 3Iron 4Iron 5Iron 6Iron 7Iron 8Iron 9Iron
  PitchingWedge GapWedge SandWedge LobWedge Putter
].freeze

# Each chart plotted per club, in display order. `field` is the CSV column;
# `abs` takes the absolute value first (for side miss); `unit`/`decimals`
# control axis and tooltip formatting. `range: [lo, hi]` makes it a "% of
# shots in range" chart (a single value per session) instead of a P25/P50/P75
# percentile chart.
METRICS = {
  distance: { field: "measurement_total_yd", label: "Total Distance", unit: " yd", decimals: 0 },
  miss: { field: "measurement_total_side_yd", label: "Absolute Side Miss", unit: " yd", decimals: 0, abs: true },
  smash: { field: "measurement_smash_factor", label: "Smash Factor", unit: "", decimals: 2 },
  face_to_path: { field: "measurement_face_to_path", label: "Face to Path", unit: "°", decimals: 1 },
  path: { field: "measurement_club_path", label: "Club Path", unit: "°", decimals: 1 },
  f2p_in_range: {
    field: "measurement_face_to_path", label: "Good Face to Path", unit: "%", decimals: 0, range: [-3, 1]
  },
  path_in_range: {
    field: "measurement_club_path", label: "Good Path", unit: "%", decimals: 0, range: [-2, 2]
  }
}.freeze

def club_sort_key(club)
  idx = CLUB_ORDER.index(club)
  idx ? [0, idx] : [1, club]
end

csv_files = Dir.glob(File.join(sessions_dir, "*.csv")).sort
if csv_files.empty?
  abort "No session CSVs found in #{sessions_dir}. Run script/fetch_sessions.rb first."
end

# club => report_id => { date:, rows: [] }
by_club = Hash.new { |h, k| h[k] = {} }

csv_files.each do |path|
  rows = CSV.read(path, headers: true).reject { |r| r["club"].to_s.strip.empty? }
  rows.group_by { |r| r["club"] }.each do |club, club_rows|
    report_id = club_rows.first["report_id"]
    date = club_rows.first["group_date"]
    session = (by_club[club][report_id] ||= { date: date, rows: [] })
    session[:rows].concat(club_rows)
  end
end

# club => chronologically sorted array of { report_id:, date:, shots:, <metric key>: {p25,p50,p75}, ... }
progress = by_club.each_with_object({}) do |(club, sessions_by_id), h|
  entries = sessions_by_id.map do |report_id, session|
    rows = session[:rows]

    percentiles = METRICS.each_with_object({}) do |(key, cfg), out|
      vals = Stats.numeric_values(rows, cfg[:field])
      vals = vals.map(&:abs) if cfg[:abs]
      out[key] = if cfg[:range]
                   { p50: Stats.pct_in_range(vals, *cfg[:range]) }
                 else
                   {
                     p25: Stats.percentile(vals, 25),
                     p50: Stats.percentile(vals, 50),
                     p75: Stats.percentile(vals, 75)
                   }
                 end
    end

    { report_id: report_id, date: session[:date], shots: rows.size }.merge(percentiles)
  end

  h[club] = entries.sort_by { |e| [e[:date], e[:report_id]] }
end

clubs = progress.keys.sort_by { |c| club_sort_key(c) }

# --- SVG chart rendering -----------------------------------------------

CHART_W = 640
CHART_H = 260
PAD_L = 46
PAD_R = 16
PAD_T = 16
PAD_B = 34

def line_chart(entries, metric, unit, decimals: 1, single: false)
  plottable = entries.select { |e| e[metric][:p50] && (single || (e[metric][:p25] && e[metric][:p75])) }
  return %(<p class="empty">Not enough data yet.</p>) if plottable.size < 2

  values = plottable.flat_map { |e| e[metric].values }
  min_v = values.min
  max_v = values.max
  span = max_v - min_v
  span = 1.0 if span.zero?
  min_v -= span * 0.15
  max_v += span * 0.15
  if single
    # percentages: keep the padded band from dipping below 0 or above 100
    min_v = [min_v, 0.0].max
    max_v = [max_v, 100.0].min
  end

  n = plottable.size
  plot_w = CHART_W - PAD_L - PAD_R
  plot_h = CHART_H - PAD_T - PAD_B

  x_for = ->(i) { PAD_L + (n == 1 ? plot_w / 2.0 : (plot_w * i) / (n - 1).to_f) }
  y_for = ->(v) { PAD_T + plot_h - ((v - min_v) / (max_v - min_v)) * plot_h }

  svg = +%(<svg viewBox="0 0 #{CHART_W} #{CHART_H}" class="chart" role="img" aria-label="#{CGI.escapeHTML(metric.to_s)} progress chart">)

  # y gridlines + labels (5 rows)
  4.downto(0) do |t|
    v = min_v + (max_v - min_v) * t / 4.0
    y = y_for.call(v)
    svg << %(<line x1="#{PAD_L}" y1="#{'%.1f' % y}" x2="#{CHART_W - PAD_R}" y2="#{'%.1f' % y}" class="grid"/>)
    svg << %(<text x="#{PAD_L - 8}" y="#{'%.1f' % (y + 3)}" class="ytick" text-anchor="end">#{format("%.#{decimals}f", v)}</text>)
  end

  # x labels: thin out when there are many sessions
  label_every = n > 9 ? (n / 8.0).ceil : 1
  plottable.each_with_index do |e, i|
    next unless (i % label_every).zero? || i == n - 1

    x = x_for.call(i)
    svg << %(<text x="#{'%.1f' % x}" y="#{CHART_H - PAD_B + 16}" class="xtick" text-anchor="middle">#{CGI.escapeHTML(e[:date][5..])}</text>)
  end

  unless single
    # shaded P25-P75 band
    upper = plottable.each_with_index.map { |e, i| [x_for.call(i), y_for.call(e[metric][:p75])] }
    lower = plottable.each_with_index.map { |e, i| [x_for.call(i), y_for.call(e[metric][:p25])] }.reverse
    band_points = (upper + lower).map { |x, y| "#{'%.1f' % x},#{'%.1f' % y}" }.join(" ")
    svg << %(<polygon points="#{band_points}" class="band"/>)

    # boundary lines (thin, dashed)
    %i[p75 p25].each do |pctl|
      pts = plottable.each_with_index.map { |e, i| "#{'%.1f' % x_for.call(i)},#{'%.1f' % y_for.call(e[metric][pctl])}" }
      svg << %(<polyline points="#{pts.join(' ')}" fill="none" class="line #{pctl}"/>)
    end
  end

  # median line (solid, bold) — the only line for a single-value metric
  median_pts = plottable.each_with_index.map { |e, i| "#{'%.1f' % x_for.call(i)},#{'%.1f' % y_for.call(e[metric][:p50])}" }
  svg << %(<polyline points="#{median_pts.join(' ')}" fill="none" class="line p50"/>)

  # dots + tooltips
  pctls = single ? %i[p50] : %i[p25 p50 p75]
  pctls.each do |pctl|
    plottable.each_with_index do |e, i|
      v = e[metric][pctl]
      x = x_for.call(i)
      y = y_for.call(v)
      prefix = single ? "" : "#{pctl.to_s.upcase} "
      label = "#{e[:date]} · #{prefix}#{format("%.#{decimals}f", v)}#{unit} · #{e[:shots]} shots"
      svg << %(<circle cx="#{'%.1f' % x}" cy="#{'%.1f' % y}" r="3.2" class="dot #{pctl}"><title>#{CGI.escapeHTML(label)}</title></circle>)
    end
  end

  svg << "</svg>"
  svg
end

# --- HTML assembly -------------------------------------------------------

sections = clubs.map do |club|
  entries = progress[club]
  first_date = entries.first[:date]
  last_date = entries.last[:date]
  total_shots = entries.sum { |e| e[:shots] }

  cards = METRICS.map do |key, cfg|
    <<~CARD
      <div class="chart-card">
        <h3>#{CGI.escapeHTML(cfg[:label])}</h3>
        #{line_chart(entries, key, cfg[:unit], decimals: cfg[:decimals], single: !!cfg[:range])}
      </div>
    CARD
  end.join

  <<~HTML
    <section class="club">
      <h2>#{CGI.escapeHTML(club)}</h2>
      <p class="meta">#{entries.size} session(s) · #{total_shots} shots · #{CGI.escapeHTML(first_date)} → #{CGI.escapeHTML(last_date)}</p>
      <div class="charts">
        #{cards}
      </div>
    </section>
  HTML
end.join("\n")

html = <<~HTML
  <!doctype html>
  <html lang="en">
  <head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>TrackMan Progress</title>
  <style>
    :root {
      color-scheme: light dark;
      --bg: #f7f7f5;
      --card-bg: #ffffff;
      --text: #1a1a1a;
      --muted: #6b6b6b;
      --border: #e3e2df;
      --grid: #e9e8e5;
      --p25: #9fc4e8;
      --p75: #f2b5a0;
      --p50: #2f6fb0;
      --band: rgba(80, 140, 200, 0.15);
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #16171a;
        --card-bg: #1f2023;
        --text: #f0f0ef;
        --muted: #9a9a97;
        --border: #34353a;
        --grid: #2c2d31;
        --p25: #6ea6d8;
        --p75: #e08a68;
        --p50: #7fb8ff;
        --band: rgba(127, 184, 255, 0.16);
      }
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      padding: 24px 16px 48px;
      background: var(--bg);
      color: var(--text);
      font: 15px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
    }
    .wrap { max-width: 1100px; margin: 0 auto; }
    h1 { font-size: 22px; margin: 0 0 4px; }
    .subtitle { color: var(--muted); margin: 0 0 20px; font-size: 13px; }
    .legend {
      display: flex; flex-wrap: wrap; gap: 16px;
      margin-bottom: 24px; padding: 10px 14px;
      background: var(--card-bg); border: 1px solid var(--border); border-radius: 8px;
      font-size: 13px; color: var(--muted);
    }
    .legend span { display: inline-flex; align-items: center; gap: 6px; white-space: nowrap; }
    .swatch { width: 12px; height: 12px; border-radius: 2px; display: inline-block; }
    .club { margin-bottom: 28px; }
    .club h2 { font-size: 17px; margin: 0 0 2px; }
    .meta { color: var(--muted); font-size: 12.5px; margin: 0 0 10px; }
    .charts {
      display: flex; flex-wrap: nowrap; gap: 16px;
      overflow-x: auto; padding-bottom: 8px; margin: 0 -16px; padding-left: 16px; padding-right: 16px;
    }
    .chart-card {
      flex: 0 0 340px; width: 340px;
      background: var(--card-bg); border: 1px solid var(--border); border-radius: 10px;
      padding: 12px 14px 6px;
    }
    .chart-card h3 { font-size: 13px; font-weight: 600; margin: 0 0 6px; color: var(--muted); }
    .chart { width: 100%; height: auto; display: block; overflow: visible; }
    .grid { stroke: var(--grid); stroke-width: 1; }
    .ytick, .xtick { fill: var(--muted); font-size: 9px; }
    .band { fill: var(--band); stroke: none; }
    .line { stroke-width: 1.5; }
    .line.p50 { stroke: var(--p50); stroke-width: 2.5; }
    .line.p25 { stroke: var(--p25); stroke-dasharray: 3 3; }
    .line.p75 { stroke: var(--p75); stroke-dasharray: 3 3; }
    .dot.p50 { fill: var(--p50); }
    .dot.p25 { fill: var(--p25); }
    .dot.p75 { fill: var(--p75); }
    .empty { color: var(--muted); font-size: 13px; }
  </style>
  </head>
  <body>
    <div class="wrap">
      <h1>TrackMan Progress</h1>
      <p class="subtitle">Generated #{Time.now.strftime('%Y-%m-%d %H:%M %Z')} from #{csv_files.size} session(s) in #{CGI.escapeHTML(sessions_dir)}.</p>
      <div class="legend">
        <span><span class="swatch" style="background:var(--p75)"></span>P75</span>
        <span><span class="swatch" style="background:var(--p50)"></span>P50 (median)</span>
        <span><span class="swatch" style="background:var(--p25)"></span>P25</span>
        <span>Shaded band = P25-P75 spread. Distance: higher and tighter is better. Side miss: lower and tighter is better. Smash Factor: higher and tighter is better. Face to Path / Club Path: tighter around your target number is better. Hover a point for exact values.</span>
      </div>
      #{sections}
    </div>
  </body>
  </html>
HTML

File.write(output_html, html)
puts "Wrote #{clubs.size} club chart(s) to #{output_html}"
