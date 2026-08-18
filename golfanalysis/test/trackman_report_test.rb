require "minitest/autorun"
require "json"
require_relative "../lib/trackman_report"

class TrackmanReportTest < Minitest::Test
  def setup
    @report = JSON.parse(File.read(File.join(__dir__, "fixtures/sample_report.json")))
  end

  def test_one_row_per_stroke
    rows = TrackmanReport::Parser.parse(@report)
    assert_equal 3, rows.size
  end

  def test_club_and_per_club_shot_numbers
    rows = TrackmanReport::Parser.parse(@report)
    seven_iron = rows.select { |r| r["club"] == "7Iron" }
    assert_equal [1, 2], seven_iron.map { |r| r["shot_number"] }

    driver = rows.select { |r| r["club"] == "Driver" }
    assert_equal [1], driver.map { |r| r["shot_number"] }
  end

  def test_session_shot_numbers_follow_chronological_order
    rows = TrackmanReport::Parser.parse(@report)
    by_session_number = rows.sort_by { |r| r["session_shot_number"] }
    assert_equal %w[stroke-1 stroke-3 stroke-2], by_session_number.map { |r| r["stroke_id"] }
  end

  def test_measurement_fields_are_flattened
    rows = TrackmanReport::Parser.parse(@report)
    row = rows.find { |r| r["stroke_id"] == "stroke-1" }

    assert_equal 30.0, row["measurement_club_speed"]
    assert_equal 40.0, row["measurement_ball_speed"]
    assert_equal 100.0, row["measurement_carry"]
    assert_equal 30.5, row["normalized_club_speed"]
    assert_equal 0.01, row["impact_location_impact_offset"]
  end

  def test_trajectories_excluded_by_default_but_available_on_request
    without = TrackmanReport::Parser.parse(@report)
    row_without = without.find { |r| r["stroke_id"] == "stroke-1" }
    refute row_without.key?("measurement_ball_trajectory")

    with = TrackmanReport::Parser.parse(@report, include_trajectories: true)
    row_with = with.find { |r| r["stroke_id"] == "stroke-1" }
    assert row_with.key?("measurement_ball_trajectory")
    assert_includes row_with["measurement_ball_trajectory"], "\"X\":1.0"
  end

  def test_report_and_group_metadata_present_on_every_row
    rows = TrackmanReport::Parser.parse(@report)
    rows.each do |row|
      assert_equal "report-1", row["report_id"]
      assert_equal "Test Range", row["group_facility_2_name"]
      assert_equal "Bay 1", row["group_bay_name"]
      assert_equal "Test Player", row["player_name"]
    end
  end

  def test_video_urls_joined
    rows = TrackmanReport::Parser.parse(@report)
    row = rows.find { |r| r["stroke_id"] == "stroke-1" }
    assert_equal "DL:https://example.com/dl.mov", row["video_urls"]
  end

  def test_csv_writer_handles_heterogeneous_rows
    rows = TrackmanReport::Parser.parse(@report)
    io = StringIO.new
    TrackmanReport::CsvWriter.write(rows, io)

    lines = io.string.lines
    assert_equal 4, lines.size # header + 3 shots
    assert_match(/\Aclub,shot_number,session_shot_number,/, lines.first)
  end
end
