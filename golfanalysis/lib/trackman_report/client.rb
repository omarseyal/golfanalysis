require "net/http"
require "uri"
require "json"

module TrackmanReport
  class Error < StandardError; end
  class RequestError < Error; end
  class InvalidUrlError < Error; end

  # Talks to the (undocumented) TrackMan "dynamic report" API that backs
  # https://web-dynamic-reports.trackmangolf.com/ pages. The page itself is a
  # JS single-page app with no server-rendered data -- it fetches the report
  # as JSON from this endpoint after load, so we skip the browser entirely
  # and call the same endpoint directly.
  class Client
    REPORT_ENDPOINT = "https://golf-player-activities.trackmangolf.com/api/reports/getreport"

    def initialize(endpoint: REPORT_ENDPOINT, open_timeout: 10, read_timeout: 30)
      @endpoint = endpoint
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    # Fetches raw report data given a full dynamic-report URL, e.g.
    #   https://web-dynamic-reports.trackmangolf.com/?r=<report-id>&nd_altitude=0&nd_temperature=25&nd_ballType=Premium
    #
    # Returns the parsed JSON response as a Hash.
    def fetch_report(url)
      report_id, normalization = parse_url(url)
      fetch_report_by_id(report_id, **normalization)
    end

    # Fetches raw report data by report id directly.
    def fetch_report_by_id(report_id, altitude: nil, temperature: nil, ball_type: nil)
      payload = {
        "ReportId" => report_id,
        "Altitude" => altitude,
        "Temperature" => temperature,
        "BallType" => ball_type
      }.compact

      post_json(@endpoint, payload)
    end

    private

    def parse_url(url)
      uri = URI.parse(url)
      params = URI.decode_www_form(uri.query.to_s).each_with_object({}) do |(k, v), h|
        h[k] = v
      end

      report_id = params["r"]
      raise InvalidUrlError, "URL is missing the report id (`r` query param): #{url}" if report_id.nil? || report_id.empty?

      normalization = {
        altitude: params["nd_altitude"]&.to_f,
        temperature: params["nd_temperature"]&.to_f,
        ball_type: params["nd_ballType"]
      }

      [report_id, normalization]
    rescue URI::InvalidURIError => e
      raise InvalidUrlError, "Could not parse URL #{url.inspect}: #{e.message}"
    end

    def post_json(url, payload)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = @open_timeout
      http.read_timeout = @read_timeout

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      request.body = JSON.generate(payload)

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        raise RequestError, "TrackMan API request failed: #{response.code} #{response.message}"
      end

      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise RequestError, "TrackMan API returned invalid JSON: #{e.message}"
    end
  end
end
