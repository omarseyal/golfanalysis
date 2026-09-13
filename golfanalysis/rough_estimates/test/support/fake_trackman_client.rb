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

  # URL parsing itself does no network I/O, so just delegate to the real
  # thing rather than re-implementing it here. Calls the instance method
  # directly on an allocated (not .new'd) object -- parse_url touches no
  # instance state, and some tests replace Client.new itself with a fake,
  # which .new here would recurse into.
  def parse_url(url)
    TrackmanReport::Client.instance_method(:parse_url).bind(TrackmanReport::Client.allocate).call(url)
  end
end
