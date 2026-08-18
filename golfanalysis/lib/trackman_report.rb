require_relative "trackman_report/version"
require_relative "trackman_report/client"
require_relative "trackman_report/flatten"
require_relative "trackman_report/parser"
require_relative "trackman_report/csv_writer"

module TrackmanReport
  # Fetches a dynamic-report URL and returns one row (Hash) per shot.
  #
  #   TrackmanReport.rows("https://web-dynamic-reports.trackmangolf.com/?r=...")
  #
  # Pass include_trajectories: true to also embed the raw BallTrajectory /
  # ClubTrajectory point clouds (JSON-encoded) in each row; off by default
  # since they're large and rarely needed alongside the scalar shot metrics.
  def self.rows(url, include_trajectories: false, client: Client.new)
    report = client.fetch_report(url)
    Parser.parse(report, include_trajectories: include_trajectories)
  end

  def self.to_csv(url, path_or_io, **opts)
    CsvWriter.write(rows(url, **opts), path_or_io)
  end
end
