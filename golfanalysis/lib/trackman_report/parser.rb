require_relative "flatten"

module TrackmanReport
  # Turns the raw TrackMan "dynamic report" JSON into a flat array of Hashes,
  # one row per shot (stroke), suitable for writing straight to CSV/a
  # dataframe. Column names are snake_case versions of TrackMan's field
  # names, prefixed by which part of the payload they came from
  # (e.g. measurement_carry, normalized_carry, impact_location_dynamic_lie).
  class Parser
    TRAJECTORY_KEYS = %w[BallTrajectory ClubTrajectory].freeze

    def self.parse(report, include_trajectories: false)
      new(report, include_trajectories: include_trajectories).rows
    end

    def initialize(report, include_trajectories: false)
      @report = report
      @include_trajectories = include_trajectories
    end

    def rows
      rows = stroke_groups.flat_map { |group| rows_for_group(group) }
      assign_session_shot_numbers(rows)
      rows
    end

    private

    attr_reader :report, :include_trajectories

    def stroke_groups
      report["StrokeGroups"] || []
    end

    def rows_for_group(group)
      strokes = group["Strokes"] || []
      group_row = group_metadata(group)

      strokes.each_with_index.map do |stroke, index|
        row = { "club" => stroke["Club"] || group["Club"], "shot_number" => index + 1 }
        row.merge!(group_row)
        row.merge!(stroke_metadata(stroke))
        row
      end
    end

    def group_metadata(group)
      {
        "group_date" => group["Date"],
        "group_ball" => group["Ball"],
        "group_target" => group["Target"],
        "group_tags" => Array(group["Tags"]).join(";"),
        "player_id" => group.dig("Player", "Id"),
        "player_name" => group.dig("Player", "Name"),
        "player_gender" => group.dig("Player", "Gender")
      }.merge(report_metadata)
    end

    def stroke_metadata(stroke)
      row = {
        "stroke_id" => stroke["Id"],
        "time" => stroke["Time"],
        "ball" => stroke["Ball"]
      }

      skip = include_trajectories ? [] : TRAJECTORY_KEYS

      Flatten.call(stroke["ImpactLocation"], prefix: "impact_location", into: row) if stroke["ImpactLocation"]
      Flatten.call(stroke["Measurement"], prefix: "measurement", skip_keys: skip, into: row) if stroke["Measurement"]
      Flatten.call(stroke["NormalizedMeasurement"], prefix: "normalized", skip_keys: skip, into: row) if stroke["NormalizedMeasurement"]
      Flatten.call(stroke["MeasurementDetails"], prefix: "measurement_details", into: row) if stroke["MeasurementDetails"]

      row["video_urls"] = Array(stroke["Videos"]).map { |v| "#{v['Angle']}:#{v['Uri']}" }.join(";")

      row
    end

    def report_metadata
      @report_metadata ||= begin
        meta = {
          "report_id" => report["Id"],
          "report_time" => report["Time"],
          "report_updated" => report["Updated"]
        }

        Flatten.call(report["Environment"], prefix: "environment", into: meta) if report["Environment"]
        Flatten.call(report["Client"], prefix: "client", into: meta) if report["Client"]

        group_by_kind(report["Groups"]).each do |kind, name|
          meta["group_#{Flatten.underscore(kind)}_name"] = name
        end

        meta
      end
    end

    def group_by_kind(groups)
      Array(groups).each_with_object({}) do |g, h|
        h[g["Kind"]] = g["Name"]
      end
    end

    def assign_session_shot_numbers(rows)
      rows.sort_by { |r| r["time"].to_s }
        .each_with_index { |r, i| r["session_shot_number"] = i + 1 }
    end
  end
end
