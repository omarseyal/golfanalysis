# Creates (or resets) a demo account with ~2 years of synthetic TrackMan
# history across a full bag, each club trending gradually better over time —
# for showing the app off without exposing anyone's real data.
#
#   DemoData.seed!    # (re)creates the account and its sessions
#   DemoData.destroy! # removes the account and everything under it
#
# Shots are inserted directly (not via TrackmanIngestor — there's no real
# report to fetch), so a session's `raw` shot payload only carries the
# fields this app actually uses, not the full ~130-column TrackMan row a
# real import would have.
module DemoData
  EMAIL = "demo@roughestimate.com"
  PASSWORD = "holeinone"
  FACILITY = "Rough Estimates Demo Range"
  SESSION_COUNT = 30
  RANDOM_SEED = 20260912

  # start/end targets interpolated linearly across every session that club
  # appears in; `sessions` is how many of the 30 session dates include it
  # (spread evenly across the whole 2 years, not clustered).
  CLUBS = [
    { name: "Driver", sessions: 14, distance: [195, 232], side_std: [20, 9], smash: [1.38, 1.47],
      club_speed: [88, 99], f2p_std: [7, 2.5], f2p_bias: [3, 0.5], path_std: [6, 2.5], path_bias: [-2, 0],
      attack: [-1, 3], carry_ratio: 0.90 },
    { name: "3Wood", sessions: 8, distance: [175, 208], side_std: [18, 8], smash: [1.30, 1.42],
      club_speed: [80, 90], f2p_std: [6, 2.3], f2p_bias: [2.5, 0.5], path_std: [5, 2.3], path_bias: [-2, 0],
      attack: [-3, -1], carry_ratio: 0.92 },
    { name: "4Hybrid", sessions: 8, distance: [160, 190], side_std: [16, 7], smash: [1.25, 1.36],
      club_speed: [76, 85], f2p_std: [5.5, 2.2], f2p_bias: [2, 0.5], path_std: [4.5, 2.2], path_bias: [-1.5, 0],
      attack: [-3, -1.5], carry_ratio: 0.94 },
    { name: "5Iron", sessions: 10, distance: [145, 172], side_std: [14, 6.5], smash: [1.20, 1.30],
      club_speed: [72, 80], f2p_std: [5, 2], f2p_bias: [2, 0.3], path_std: [4, 2], path_bias: [-1.5, 0],
      attack: [-4, -2.5], carry_ratio: 0.96 },
    { name: "6Iron", sessions: 10, distance: [133, 158], side_std: [13, 6], smash: [1.18, 1.27],
      club_speed: [69, 76], f2p_std: [4.7, 1.9], f2p_bias: [1.8, 0.3], path_std: [3.8, 1.9], path_bias: [-1.3, 0],
      attack: [-4, -2.5], carry_ratio: 0.965 },
    { name: "7Iron", sessions: 16, distance: [120, 145], side_std: [12, 5.5], smash: [1.16, 1.25],
      club_speed: [66, 73], f2p_std: [4.5, 1.8], f2p_bias: [1.7, 0.3], path_std: [3.6, 1.8], path_bias: [-1.2, 0],
      attack: [-4, -3], carry_ratio: 0.97 },
    { name: "8Iron", sessions: 10, distance: [108, 131], side_std: [11, 5], smash: [1.14, 1.23],
      club_speed: [63, 69], f2p_std: [4.3, 1.7], f2p_bias: [1.6, 0.2], path_std: [3.4, 1.7], path_bias: [-1.1, 0],
      attack: [-4.5, -3], carry_ratio: 0.975 },
    { name: "9Iron", sessions: 16, distance: [95, 118], side_std: [10, 4.5], smash: [1.12, 1.21],
      club_speed: [60, 66], f2p_std: [4, 1.6], f2p_bias: [1.5, 0.2], path_std: [3.2, 1.6], path_bias: [-1, 0],
      attack: [-4.5, -3], carry_ratio: 0.98 },
    { name: "PitchingWedge", sessions: 12, distance: [80, 102], side_std: [9, 4], smash: [1.08, 1.18],
      club_speed: [56, 62], f2p_std: [3.8, 1.5], f2p_bias: [1.4, 0.2], path_std: [3, 1.5], path_bias: [-0.9, 0],
      attack: [-5, -3.5], carry_ratio: 0.985 },
    { name: "GapWedge", sessions: 8, distance: [68, 88], side_std: [8, 3.7], smash: [1.05, 1.15],
      club_speed: [52, 58], f2p_std: [3.6, 1.4], f2p_bias: [1.3, 0.2], path_std: [2.8, 1.4], path_bias: [-0.8, 0],
      attack: [-5, -3.5], carry_ratio: 0.99 },
    { name: "SandWedge", sessions: 8, distance: [55, 75], side_std: [7, 3.5], smash: [1.00, 1.10],
      club_speed: [48, 54], f2p_std: [3.4, 1.3], f2p_bias: [1.2, 0.2], path_std: [2.6, 1.3], path_bias: [-0.7, 0],
      attack: [-5, -3.5], carry_ratio: 0.995 }
  ].freeze

  def self.seed!
    destroy!
    srand(RANDOM_SEED)

    user = User.create!(email: EMAIL, password: PASSWORD, name: "Demo Golfer")
    dates = session_dates

    # club => list of session indices it appears in, spread evenly across
    # the whole range so every club shows progress from early to late.
    indices_by_club = CLUBS.index_with { |club| evenly_spaced_indices(club[:sessions], dates.size) }

    dates.each_with_index do |date, session_index|
      clubs_today = CLUBS.select { |club| indices_by_club[club].include?(session_index) }
      next if clubs_today.empty?

      build_session(user, date, session_index, dates.size, clubs_today)
    end

    user
  end

  def self.destroy!
    User.where(email: EMAIL).destroy_all
  end

  def self.session_dates
    end_date = Date.current - 2
    start_date = end_date - 2.years
    span = (end_date - start_date).to_i

    (0...SESSION_COUNT).map { |i| start_date + (i * span / (SESSION_COUNT - 1).to_f).round }
  end

  def self.evenly_spaced_indices(count, total)
    return [total - 1] if count <= 1

    (0...count).map { |j| (j * (total - 1) / (count - 1).to_f).round }.uniq
  end
  private_class_method :evenly_spaced_indices

  def self.build_session(user, date, session_index, total_sessions, clubs_today)
    t = session_index / (total_sessions - 1).to_f
    report_id = SecureRandom.uuid

    session = user.trackman_sessions.create!(
      report_id: report_id,
      source_url: "demo://rough-estimates/#{report_id}",
      session_date: date,
      facility: FACILITY,
      bay: "Bay #{(session_index % 4) + 1}",
      player_name: user.name,
      shot_count: 0,
      fetched_at: date.to_time
    )

    session_shot_number = 0
    rows = clubs_today.flat_map do |club|
      club_shot_number = 0
      shots_for_club(club, t).map do |attrs|
        session_shot_number += 1
        club_shot_number += 1
        row = attrs.merge(
          trackman_session_id: session.id, club: club[:name],
          shot_number: club_shot_number, session_shot_number: session_shot_number,
          created_at: Time.current, updated_at: Time.current
        )
        row[:raw] = raw_row(row, date, user, report_id).to_json
        row
      end
    end

    Shot.insert_all!(rows)
    session.update!(shot_count: rows.size)
  end
  private_class_method :build_session

  def self.shots_for_club(club, t)
    lerp = ->(range) { range[0] + (range[1] - range[0]) * t }

    mean_distance = lerp.call(club[:distance])
    side_std = lerp.call(club[:side_std])
    smash_mean = lerp.call(club[:smash])
    club_speed_mean = lerp.call(club[:club_speed])
    f2p_std = lerp.call(club[:f2p_std])
    f2p_bias = lerp.call(club[:f2p_bias])
    path_std = lerp.call(club[:path_std])
    path_bias = lerp.call(club[:path_bias])
    attack_mean = lerp.call(club[:attack])
    distance_std = side_std * 0.7

    Array.new(rand(18..40)) do
      total = mean_distance + gaussian(std: distance_std)
      smash_factor = (smash_mean + gaussian(std: 0.03)).clamp(0.9, 1.55)
      club_speed = club_speed_mean + gaussian(std: club_speed_mean * 0.04)

      {
        total: total,
        total_side: gaussian(std: side_std),
        carry: total * club[:carry_ratio] + gaussian(std: distance_std * 0.3),
        smash_factor: smash_factor,
        club_speed: club_speed,
        ball_speed: club_speed * smash_factor,
        face_to_path: f2p_bias + gaussian(std: f2p_std),
        club_path: path_bias + gaussian(std: path_std),
        attack_angle: attack_mean + gaussian(std: 1.0)
      }
    end
  end
  private_class_method :shots_for_club

  def self.raw_row(row, date, user, report_id)
    {
      "club" => row[:club],
      "shot_number" => row[:shot_number],
      "session_shot_number" => row[:session_shot_number],
      "group_date" => date.iso8601,
      "player_name" => user.name,
      "group_facility_2_name" => FACILITY,
      "group_bay_name" => "Bay #{(row[:session_shot_number] % 4) + 1}",
      "report_id" => report_id,
      "measurement_total" => row[:total],
      "measurement_total_side" => row[:total_side],
      "measurement_carry" => row[:carry],
      "measurement_smash_factor" => row[:smash_factor],
      "measurement_club_speed" => row[:club_speed],
      "measurement_ball_speed" => row[:ball_speed],
      "measurement_face_to_path" => row[:face_to_path],
      "measurement_club_path" => row[:club_path],
      "measurement_attack_angle" => row[:attack_angle]
    }
  end
  private_class_method :raw_row

  # Box-Muller: turns two uniform randoms into one normally-distributed one.
  def self.gaussian(mean: 0.0, std: 1.0)
    u1 = [rand, 1e-9].max
    u2 = rand
    mean + Math.sqrt(-2.0 * Math.log(u1)) * Math.cos(2 * Math::PI * u2) * std
  end
  private_class_method :gaussian
end
