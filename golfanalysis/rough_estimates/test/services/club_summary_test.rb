require "test_helper"

class ClubSummaryTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "golfer@example.com", password: "password123")
    @session = @user.trackman_sessions.create!(
      report_id: "r-1", source_url: "https://example.com?r=r-1",
      session_date: "2026-01-01", shot_count: 3, fetched_at: Time.current
    )
    now = Time.current
    Shot.insert_all!([
      { trackman_session_id: @session.id, club: "7Iron", total: 100.0, total_side: 5.0,
        smash_factor: 1.3, club_speed: 75.0, ball_speed: 97.5, carry: 90.0,
        face_to_path: -1.0, club_path: -1.0, raw: "{}", created_at: now, updated_at: now },
      { trackman_session_id: @session.id, club: "7Iron", total: 110.0, total_side: -5.0,
        smash_factor: 1.3, club_speed: 76.0, ball_speed: 98.8, carry: 95.0,
        face_to_path: 0.0, club_path: 0.0, raw: "{}", created_at: now, updated_at: now },
      { trackman_session_id: @session.id, club: "Driver", total: 220.0, total_side: 10.0,
        smash_factor: 1.48, club_speed: 100.0, ball_speed: 148.0, carry: 210.0,
        face_to_path: 5.0, club_path: 5.0, raw: "{}", created_at: now, updated_at: now }
    ])
  end

  test "groups by club with shot counts" do
    clubs = ClubSummary.for_session(@session)
    by_name = clubs.index_by { |c| c[:club] }

    assert_equal 2, by_name["7Iron"][:shots]
    assert_equal 1, by_name["Driver"][:shots]
  end

  test "computes averages for the configured fields" do
    seven_iron = ClubSummary.for_session(@session).find { |c| c[:club] == "7Iron" }
    assert_in_delta 105.0, seven_iron[:averages]["Total"][:mean]
    assert_in_delta 1.3, seven_iron[:averages]["Smash Factor"][:mean]
  end

  test "computes dispersion including absolute side miss distance" do
    seven_iron = ClubSummary.for_session(@session).find { |c| c[:club] == "7Iron" }
    d = seven_iron[:dispersion]

    assert_in_delta 5.0, d[:side_miss_distance_mean]
    assert_in_delta 0.0, d[:side_abs_avg_miss]
    assert_in_delta 100.0, d[:f2p_pct_in_range]
  end
end
