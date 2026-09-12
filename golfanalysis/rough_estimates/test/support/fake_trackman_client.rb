# A stand-in for TrackmanReport::Client that returns a fixed fixture instead
# of hitting the network, for tests that exercise TrackmanIngestor.
class FakeTrackmanClient
  FIXTURE = Rails.root.join("test/fixtures/files/sample_report.json")

  def initialize(report_path: FIXTURE)
    @report = JSON.parse(File.read(report_path))
  end

  def fetch_report(_url)
    @report
  end
end
