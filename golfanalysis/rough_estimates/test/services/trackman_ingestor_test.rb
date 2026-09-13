require "test_helper"

class TrackmanIngestorTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "golfer@example.com", password: "password123")
    @url = "https://web-dynamic-reports.trackmangolf.com/?r=test-report-1&dm=c"
  end

  test "creates a session and its shots from the report" do
    result = TrackmanIngestor.call(user: @user, url: @url, client: FakeTrackmanClient.new)

    assert result.ok?
    assert result.created?
    session = result.session
    assert_equal "test-report-1", session.report_id
    assert_equal 3, session.shot_count
    assert_equal Date.new(2026, 1, 1), session.session_date
    assert_equal %w[7Iron Driver].sort, session.clubs.sort
    assert_equal 3, session.shots.count
    assert session.shots.first.raw.present?
  end

  test "is idempotent by report id for the same user" do
    first = TrackmanIngestor.call(user: @user, url: @url, client: FakeTrackmanClient.new)

    assert_no_difference -> { TrackmanSession.count } do
      second = TrackmanIngestor.call(user: @user, url: @url, client: FakeTrackmanClient.new)
      assert second.ok?
      refute second.created?
      assert_equal first.session.id, second.session.id
    end
  end

  test "filters shots to the user's player_name when set" do
    @user.update!(player_name: "Someone Else")

    result = TrackmanIngestor.call(user: @user, url: @url, client: FakeTrackmanClient.new)

    refute result.ok?
    assert_match(/no shots/i, result.error)
  end

  test "rejects a url with no report id" do
    result = TrackmanIngestor.call(user: @user, url: "https://example.com/not-a-report", client: FakeTrackmanClient.new)

    refute result.ok?
    assert_match(/report/i, result.error)
  end

  test "also accepts an activity link (?a=...), storing the activity id as report_id" do
    url = "https://web-dynamic-reports.trackmangolf.com/?a=test-activity-1&dm=c&sgos%5B%5D=test-activity-1"

    result = TrackmanIngestor.call(user: @user, url: url, client: FakeTrackmanClient.new)

    assert result.ok?
    assert_equal "test-activity-1", result.session.report_id
  end

  test "stores distance/speed in real-world units, not TrackMan's raw metric ones" do
    result = TrackmanIngestor.call(user: @user, url: @url, client: FakeTrackmanClient.new)

    shot = result.session.shots.find_by!(club: "7Iron", shot_number: 1)
    # fixture's raw metric values: ClubSpeed 30 m/s, BallSpeed 40 m/s, Carry 100 m
    assert_in_delta 30.0 * TrackmanReport::Units::MPS_TO_MPH, shot.club_speed
    assert_in_delta 40.0 * TrackmanReport::Units::MPS_TO_MPH, shot.ball_speed
    assert_in_delta 100.0 * TrackmanReport::Units::M_TO_YD, shot.carry
  end

  test "refresh! re-fetches a session from its own source_url and replaces its shots" do
    original = TrackmanIngestor.call(user: @user, url: @url, client: FakeTrackmanClient.new).session
    original_shot_id = original.shots.first.id

    result = TrackmanIngestor.refresh!(original, client: FakeTrackmanClient.new)

    assert result.ok?
    assert_equal original.id, result.session.id
    assert_equal 3, result.session.shots.count
    refute result.session.shots.exists?(original_shot_id), "expected the old shot rows to be replaced"
  end
end
