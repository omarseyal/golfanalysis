require "test_helper"

class ClubsApiTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "golfer@example.com", password: "password123", player_name: "Omar")
    # 7Iron: 4 sessions x 16 shots = 64 (unlocked); PitchingWedge: 10 shots, one old session.
    [ "2026-09-01", "2026-09-10", "2026-09-20", "2026-10-01" ].each_with_index do |date, i|
      add_session(date, "7Iron", 16, carry: 150 + i * 2, side: i.even? ? 4 : -4)
    end
    add_session("2026-06-01", "PitchingWedge", 10, carry: 110, side: 2)
  end

  def add_session(date, club, n, carry:, side:)
    s = @user.trackman_sessions.create!(report_id: "r-#{date}-#{club}", source_url: "https://example.com?r=#{date}",
      session_date: date, shot_count: n, fetched_at: Time.current)
    n.times do |k|
      jitter = (k % 5) - 2
      Shot.create!(trackman_session: s, club: club, shot_number: k + 1, session_shot_number: k + 1,
        carry: carry + jitter, total: carry + 10 + jitter, total_side: side + jitter, smash_factor: 1.33,
        face_to_path: -1.0 + jitter * 0.1, club_path: 0.5, face_angle: 0.0, club_speed: 80.0, raw: "{}")
    end
  end

  test "the read-only game token works as a header or a query param, and so does the api key" do
    get api_v1_clubs_path, headers: { "Authorization" => "Bearer #{@user.game_token}" }
    assert_response :success
    get api_v1_clubs_path(token: @user.game_token)
    assert_response :success
    get api_v1_clubs_path, headers: { "Authorization" => "Bearer #{@user.api_key}" }
    assert_response :success
  end

  test "the game token can't use the rest of the API" do
    get api_v1_sessions_path, headers: { "Authorization" => "Bearer #{@user.game_token}" }
    assert_response :unauthorized
  end

  test "a bad token is a 401 that a browser can still read" do
    get api_v1_clubs_path(token: "nope")
    assert_response :unauthorized
    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
  end

  test "CORS preflight is answered" do
    process :options, api_v1_clubs_path
    assert_response :no_content
    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
    assert_match "Authorization", response.headers["Access-Control-Allow-Headers"]
  end

  test "overview: clubs in bag order, unlocked vs locked, gapping falls back to all-time for a stale club" do
    get api_v1_clubs_path(token: @user.game_token, window: "14")
    body = JSON.parse(response.body)

    assert_equal "Omar", body.dig("player", "name")
    assert_equal 74, body["shots"]
    assert_equal %w[7Iron PitchingWedge], body["clubs"].map { |c| c["club"] }

    iron, wedge = body["clubs"]
    assert iron["unlocked"]
    assert_equal %w[carry total aside smash path f2p], iron["stats"].keys
    assert_equal "better", iron["stats"]["carry"]["trend"]

    refute wedge["unlocked"]
    assert_equal 50, wedge["shots_to_unlock"]
    assert_equal 110.0, wedge["median_carry_so_far"]
    # nothing in the last 2 weeks: all its shots, flagged stale
    assert wedge.dig("gapping", "carry", "stale")
    assert_equal "2026-06-01", wedge.dig("gapping", "carry", "last_hit")
    # the 14 days up to the last session (Oct 1) hold the Sep 20 and Oct 1 sessions
    assert_equal 32, iron.dig("gapping", "carry", "shots")
    refute iron.dig("gapping", "carry", "stale")
  end

  test "one club's page" do
    get api_v1_club_path("7Iron", token: @user.game_token)
    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 64, body["shots"]
    assert_equal 4, body["sessions"]
    assert_equal 4, body["session_log"].size
    assert_equal "better", body.dig("stories", "carry", "verdict")
    assert_equal 64, body.dig("distribution", "carry", "shots")
    assert body.dig("dispersion", "all_shots", "major_yd").positive?
    assert_equal 4, body.dig("is_it_real", "carry", "sessions")
  end

  test "an unknown club is a 404 listing the clubs there are" do
    get api_v1_club_path("Putter", token: @user.game_token)
    assert_response :not_found
    assert_equal %w[7Iron PitchingWedge], JSON.parse(response.body)["clubs"]
  end
end
