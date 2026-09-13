require "test_helper"

class AnalysisDataTest < ActiveSupport::TestCase
  test "builds a compact per-shot dataset indexed by date and club" do
    user = User.create!(email: "golfer@example.com", password: "password123")
    session = user.trackman_sessions.create!(
      report_id: "r-1", source_url: "https://example.com?r=r-1",
      session_date: "2026-01-01", shot_count: 1, fetched_at: Time.current
    )
    Shot.create!(
      trackman_session: session, club: "7Iron", shot_number: 1, session_shot_number: 1,
      carry: 150.0, total: 160.0, total_side: 5.0, smash_factor: 1.3,
      face_to_path: 1.0, club_path: -0.5, face_angle: 0.5, club_speed: 75.0, raw: "{}"
    )

    data = AnalysisData.for_user(user)

    assert_equal ["2026-01-01"], data[:dates]
    assert_equal ["7Iron"], data[:clubs]
    assert_equal %w[date club carry total side smash f2p path face clubSpeed], data[:cols]
    assert_equal [[0, 0, 150.0, 160.0, 5.0, 1.3, 1.0, -0.5, 0.5, 75.0]], data[:rows]
  end

  test "excludes shots with no club" do
    user = User.create!(email: "golfer@example.com", password: "password123")
    session = user.trackman_sessions.create!(
      report_id: "r-1", source_url: "https://example.com?r=r-1",
      session_date: "2026-01-01", shot_count: 1, fetched_at: Time.current
    )
    Shot.create!(trackman_session: session, club: nil, shot_number: 1, total: 100.0, raw: "{}")

    data = AnalysisData.for_user(user)

    assert_empty data[:rows]
  end
end
