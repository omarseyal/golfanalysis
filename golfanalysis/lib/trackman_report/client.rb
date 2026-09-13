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
    ACTIVITY_REPORT_ENDPOINT = "https://golf-player-activities.trackmangolf.com/api/reports/getactivityreport"

    def initialize(endpoint: REPORT_ENDPOINT, activity_endpoint: ACTIVITY_REPORT_ENDPOINT, open_timeout: 10, read_timeout: 30)
      @endpoint = endpoint
      @activity_endpoint = activity_endpoint
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    # Fetches raw report data given a full dynamic-report URL. Handles both
    # link styles TrackMan hands out:
    #   ...?r=<report-id>&...    a single report
    #   ...?a=<activity-id>&...  a "multi group" report covering every
    #                            stroke group under that activity -- a
    #                            different API endpoint and payload key, not
    #                            just an alias for `r`
    #
    # Returns the parsed JSON response as a Hash (same shape either way:
    # Parser doesn't need to know which kind of link it came from).
    def fetch_report(url)
      id, kind, normalization = parse_url(url)

      case kind
      when :report then fetch_report_by_id(id, **normalization)
      when :activity then fetch_activity_report_by_id(id, **normalization)
      end
    end

    # Fetches raw report data by report id directly.
    def fetch_report_by_id(report_id, altitude: nil, temperature: nil, ball_type: nil)
      post_json(@endpoint, request_payload("ReportId", report_id, altitude, temperature, ball_type))
    end

    # Fetches raw report data by activity id directly.
    def fetch_activity_report_by_id(activity_id, altitude: nil, temperature: nil, ball_type: nil)
      post_json(@activity_endpoint, request_payload("ActivityId", activity_id, altitude, temperature, ball_type))
    end

    # Parses a dynamic-report URL into [id, kind, normalization], where kind
    # is :report (from an `r`/`ReportId` param) or :activity (from an `a`
    # param). Public (rather than the usual leading-underscore-free private
    # convention) so it can be unit tested without hitting the network.
    def parse_url(url)
      uri = URI.parse(url)
      params = URI.decode_www_form(uri.query.to_s).each_with_object({}) { |(k, v), h| h[k] = v }

      normalization = {
        altitude: params["nd_altitude"]&.to_f,
        temperature: params["nd_temperature"]&.to_f,
        ball_type: params["nd_ballType"]
      }

      report_id = params["r"] || params["ReportId"]
      activity_id = params["a"]

      if report_id && !report_id.empty?
        [report_id, :report, normalization]
      elsif activity_id && !activity_id.empty?
        [activity_id, :activity, normalization]
      else
        raise InvalidUrlError,
          "URL is missing a report id (`r`/`ReportId`) or activity id (`a`) query param: #{url}"
      end
    rescue URI::InvalidURIError => e
      raise InvalidUrlError, "Could not parse URL #{url.inspect}: #{e.message}"
    end

    private

    def request_payload(id_key, id_value, altitude, temperature, ball_type)
      { id_key => id_value, "Altitude" => altitude, "Temperature" => temperature, "BallType" => ball_type }.compact
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
