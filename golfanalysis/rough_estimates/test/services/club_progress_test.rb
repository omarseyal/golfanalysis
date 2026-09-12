require "test_helper"

class ClubProgressTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "golfer@example.com", password: "password123")
  end

  def make_session(date:, totals:, sides: nil, f2p: nil)
    session = @user.trackman_sessions.create!(
      report_id: "r-#{date}", source_url: "https://example.com?r=r-#{date}",
      session_date: date, shot_count: totals.size, fetched_at: Time.current
    )
    now = Time.current
    Shot.insert_all!(totals.each_with_index.map { |total, i|
      {
        trackman_session_id: session.id, club: "7Iron", shot_number: i + 1,
        total: total, total_side: sides ? sides[i] : 0.0, face_to_path: f2p ? f2p[i] : 0.0,
        raw: "{}", created_at: now, updated_at: now
      }
    })
    session
  end

  test "builds chronological per-club percentile series" do
    make_session(date: "2026-02-01", totals: [90, 100, 110])
    make_session(date: "2026-01-01", totals: [80, 85, 90])

    progress = ClubProgress.build(@user.trackman_sessions)

    entries = progress["7Iron"]
    assert_equal 2, entries.size
    assert_equal ["2026-01-01", "2026-02-01"], entries.map { |e| e[:date].to_s }
    assert_in_delta 85, entries.first[:distance][:p50]
    assert_in_delta 100, entries.last[:distance][:p50]
  end

  test "orders clubs by CLUB_ORDER, unknown clubs last alphabetically" do
    assert_equal [0, ClubProgress::CLUB_ORDER.index("7Iron")], ClubProgress.club_sort_key("7Iron")
    assert_equal [1, "Zzz"], ClubProgress.club_sort_key("Zzz")
  end

  test "a range metric produces a single pct_in_range value, not p25/p75" do
    make_session(date: "2026-01-01", totals: [90, 100], f2p: [-1, 5])

    entries = ClubProgress.build(@user.trackman_sessions)["7Iron"]

    assert_equal 50.0, entries.first[:f2p_in_range][:p50]
    refute entries.first[:f2p_in_range].key?(:p25)
  end
end
