#!/usr/bin/env ruby
# Fetches every TrackMan dynamic-report URL in urls.txt, writes one detail
# CSV per session to output/sessions/, and writes a Markdown summary
# (session list + per-club averages) to output/summary.md.
#
# Usage: ruby script/fetch_sessions.rb [urls_file] [output_dir]

require_relative "../lib/trackman_report"

urls_file = ARGV[0] || File.join(__dir__, "urls.txt")
output_dir = ARGV[1] || File.join(__dir__, "..", "output")
sessions_dir = File.join(output_dir, "sessions")

Dir.mkdir(output_dir) unless Dir.exist?(output_dir)
Dir.mkdir(sessions_dir) unless Dir.exist?(sessions_dir)

EXCLUDED_PLAYERS = ["Naureen Seyal"].freeze

AVG_FIELDS = {
  "measurement_club_speed_mph" => "Club Speed",
  "measurement_ball_speed_mph" => "Ball Speed",
  "measurement_smash_factor" => "Smash Factor",
  "measurement_carry_yd" => "Carry",
  "measurement_total_yd" => "Total"
}.freeze

Stats = TrackmanReport::Stats

client = TrackmanReport::Client.new

# Handles both link styles TrackMan hands out -- ?r=<report-id> and the
# "multi group" ?a=<activity-id> -- via Client#parse_url, so a URL's id
# here always matches what fetch_report will actually fetch.
def report_id_from_url(client, url)
  client.parse_url(url).first
rescue TrackmanReport::InvalidUrlError
  nil
end

urls = File.readlines(urls_file, chomp: true).reject(&:empty?)
seen_report_ids = {}
deduped = urls.select do |url|
  id = report_id_from_url(client, url)
  next false unless url.start_with?("https://web-dynamic-reports.trackmangolf.com/")
  next false if seen_report_ids[id]

  seen_report_ids[id] = true
  true
end

puts "#{urls.size} URLs -> #{deduped.size} unique TrackMan reports"

sessions = []

deduped.each_with_index do |url, i|
  report_id = report_id_from_url(client, url)
  print "[#{i + 1}/#{deduped.size}] #{report_id} ... "

  begin
    report = client.fetch_report(url)
    rows = TrackmanReport::Parser.parse(report)

    excluded_count = rows.count { |r| EXCLUDED_PLAYERS.include?(r["player_name"]) }
    rows = rows.reject { |r| EXCLUDED_PLAYERS.include?(r["player_name"]) }

    if rows.empty?
      puts "no shots (all #{excluded_count} excluded), skipping"
      next
    end

    date = rows.first["group_date"]
    facility = rows.first["group_facility_2_name"] || rows.first["group_location_name"]
    bay = rows.first["group_bay_name"]
    player = rows.first["player_name"]

    csv_name = "#{date}_#{report_id[0, 8]}.csv"
    TrackmanReport::CsvWriter.write(rows, File.join(sessions_dir, csv_name))

    clubs = rows.group_by { |r| r["club"] }.map do |club, club_rows|
      averages = AVG_FIELDS.each_with_object({}) do |(field, label), h|
        values = Stats.numeric_values(club_rows, field)
        h[label] = {
          mean: Stats.mean(values),
          median: Stats.median(values),
          p25: Stats.percentile(values, 25),
          p75: Stats.percentile(values, 75)
        }
      end

      side_vals = Stats.numeric_values(club_rows, "measurement_total_side_yd")
      abs_side_vals = side_vals.map(&:abs)
      f2p_vals = Stats.numeric_values(club_rows, "measurement_face_to_path")
      path_vals = Stats.numeric_values(club_rows, "measurement_club_path")

      dispersion = {
        side_variance: Stats.variance(side_vals),
        side_abs_avg_miss: (Stats.mean(side_vals) ? Stats.mean(side_vals).abs : nil),
        side_abs_median_miss: (Stats.median(side_vals) ? Stats.median(side_vals).abs : nil),
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

      { club: club, shots: club_rows.size, averages: averages, dispersion: dispersion }
    end

    sessions << {
      report_id: report_id,
      date: date,
      facility: facility,
      bay: bay,
      player: player,
      total_shots: rows.size,
      csv: "sessions/#{csv_name}",
      clubs: clubs.sort_by { |c| -c[:shots] }
    }

    excluded_note = excluded_count.positive? ? ", #{excluded_count} excluded" : ""
    puts "ok (#{rows.size} shots, #{clubs.size} club(s)#{excluded_note})"
  rescue TrackmanReport::Error => e
    puts "FAILED: #{e.message}"
    sessions << { report_id: report_id, error: e.message }
  end
end

sessions.sort_by! { |s| s[:date].to_s }

md = +"# TrackMan Session Summary\n\n"
md << "Generated #{Time.now.strftime('%Y-%m-%d %H:%M %Z')} from #{deduped.size} unique report(s).\n\n"

failed = sessions.select { |s| s[:error] }
ok = sessions.reject { |s| s[:error] }

md << "## Sessions\n\n"
md << "| Date | Facility | Bay | Player | Total Shots | Clubs | CSV |\n"
md << "|---|---|---|---|---|---|---|\n"
ok.each do |s|
  club_list = s[:clubs].map { |c| "#{c[:club]} (#{c[:shots]})" }.join(", ")
  md << "| #{s[:date]} | #{s[:facility]} | #{s[:bay]} | #{s[:player]} | #{s[:total_shots]} | #{club_list} | [#{s[:csv]}](#{s[:csv]}) |\n"
end

md << "\n## Per-Club Averages\n\n"
md << "Each cell is Mean / Median. Carry and Smash Factor also show the 25th-75th percentile range.\n\n"
ok.each do |s|
  md << "### #{s[:date]} — #{s[:facility]} (`#{s[:report_id]}`)\n\n"
  md << "| Club | Shots | Club Speed | Ball Speed | Smash Factor | Smash Factor P25-P75 | Carry | Carry P25-P75 | Total |\n"
  md << "|---|---|---|---|---|---|---|---|---|\n"
  fmt = ->(v) { v.nil? ? "-" : format("%.1f", v) }
  stat = ->(h) { "#{fmt.call(h[:mean])} / #{fmt.call(h[:median])}" }
  iqr = ->(h) { "#{fmt.call(h[:p25])} - #{fmt.call(h[:p75])}" }
  s[:clubs].each do |c|
    a = c[:averages]
    md << "| #{c[:club]} | #{c[:shots]} | #{stat.call(a['Club Speed'])} | #{stat.call(a['Ball Speed'])} | " \
          "#{stat.call(a['Smash Factor'])} | #{iqr.call(a['Smash Factor'])} | " \
          "#{stat.call(a['Carry'])} | #{iqr.call(a['Carry'])} | #{stat.call(a['Total'])} |\n"
  end
  md << "\n"
end

md << "\n## Per-Club Dispersion & Face/Path Consistency\n\n"
md << "Side miss uses Total Side (yards, +right/-left). Face-to-Path and Path are in degrees. " \
      "\"% in range\" is the share of shots with Face-to-Path between -3 and +1 degrees, " \
      "or Path between -2 and +2 degrees. Miss/Avg/Path cells are Mean / Median " \
      "(Side Miss shown as absolute value).\n\n"
ok.each do |s|
  md << "### #{s[:date]} — #{s[:facility]} (`#{s[:report_id]}`)\n\n"
  md << "| Club | Shots | Side Var | \\|Side Miss\\| | F2P Var | F2P | F2P % in [-3,+1] | Path Var | Path | Path % in [-2,+2] |\n"
  md << "|---|---|---|---|---|---|---|---|---|---|\n"
  fmt = ->(v) { v.nil? ? "-" : format("%.1f", v) }
  pct = ->(v) { v.nil? ? "-" : format("%.0f%%", v) }
  s[:clubs].each do |c|
    d = c[:dispersion]
    side_miss = "#{fmt.call(d[:side_abs_avg_miss])} / #{fmt.call(d[:side_abs_median_miss])}"
    f2p = "#{fmt.call(d[:f2p_avg])} / #{fmt.call(d[:f2p_median])}"
    path = "#{fmt.call(d[:path_avg])} / #{fmt.call(d[:path_median])}"
    md << "| #{c[:club]} | #{c[:shots]} | #{fmt.call(d[:side_variance])} | #{side_miss} | " \
          "#{fmt.call(d[:f2p_variance])} | #{f2p} | #{pct.call(d[:f2p_pct_in_range])} | " \
          "#{fmt.call(d[:path_variance])} | #{path} | #{pct.call(d[:path_pct_in_range])} |\n"
  end
  md << "\n"
end

md << "\n## Per-Club Absolute Side Miss Distance\n\n"
md << "Side miss uses Total Side (yards). Each shot's miss is taken as an absolute value " \
      "before averaging, so a foot left and a foot right both count the same.\n\n"
ok.each do |s|
  md << "### #{s[:date]} — #{s[:facility]} (`#{s[:report_id]}`)\n\n"
  md << "| Club | Shots | Mean | P25 | P50 (Median) | P75 |\n"
  md << "|---|---|---|---|---|---|\n"
  fmt = ->(v) { v.nil? ? "-" : format("%.1f", v) }
  s[:clubs].each do |c|
    d = c[:dispersion]
    md << "| #{c[:club]} | #{c[:shots]} | #{fmt.call(d[:side_miss_distance_mean])} | " \
          "#{fmt.call(d[:side_miss_distance_p25])} | #{fmt.call(d[:side_miss_distance_p50])} | " \
          "#{fmt.call(d[:side_miss_distance_p75])} |\n"
  end
  md << "\n"
end

unless failed.empty?
  md << "## Failed to Fetch\n\n"
  failed.each { |s| md << "- `#{s[:report_id]}`: #{s[:error]}\n" }
end

summary_path = File.join(output_dir, "summary.md")
File.write(summary_path, md)

puts "\nWrote #{ok.size} session CSVs to #{sessions_dir}"
puts "Wrote summary to #{summary_path}"
puts "#{failed.size} report(s) failed" unless failed.empty?
