require "minitest/autorun"
require_relative "../lib/trackman_report"

class ClientTest < Minitest::Test
  def setup
    @client = TrackmanReport::Client.new
  end

  def test_parses_r_param_as_a_report_link
    id, kind, = @client.parse_url("https://web-dynamic-reports.trackmangolf.com/?r=abc-123&dm=c")
    assert_equal "abc-123", id
    assert_equal :report, kind
  end

  def test_parses_reportid_param_as_a_report_link
    id, kind, = @client.parse_url("https://web-dynamic-reports.trackmangolf.com/?ReportId=abc-123")
    assert_equal "abc-123", id
    assert_equal :report, kind
  end

  def test_parses_a_param_as_an_activity_link
    id, kind, = @client.parse_url("https://web-dynamic-reports.trackmangolf.com/?a=xyz-789&dm=c&sgos%5B%5D=xyz-789")
    assert_equal "xyz-789", id
    assert_equal :activity, kind
  end

  def test_prefers_r_over_a_when_somehow_both_are_present
    id, kind, = @client.parse_url("https://web-dynamic-reports.trackmangolf.com/?r=abc-123&a=xyz-789")
    assert_equal "abc-123", id
    assert_equal :report, kind
  end

  def test_extracts_normalization_params
    _id, _kind, normalization = @client.parse_url(
      "https://web-dynamic-reports.trackmangolf.com/?r=abc-123&nd_altitude=100&nd_temperature=20&nd_ballType=Premium"
    )
    assert_in_delta 100.0, normalization[:altitude]
    assert_in_delta 20.0, normalization[:temperature]
    assert_equal "Premium", normalization[:ball_type]
  end

  def test_raises_when_neither_id_param_is_present
    assert_raises(TrackmanReport::InvalidUrlError) do
      @client.parse_url("https://web-dynamic-reports.trackmangolf.com/?dm=c")
    end
  end

  def test_raises_on_unparseable_url
    assert_raises(TrackmanReport::InvalidUrlError) do
      @client.parse_url("http://[invalid")
    end
  end
end
