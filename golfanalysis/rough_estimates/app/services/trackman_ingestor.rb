# Fetches a TrackMan dynamic-report URL and persists it as a TrackmanSession
# (+ one Shot per stroke) for the given user, reusing the TrackmanReport
# library's HTTP client and parser. Idempotent: re-ingesting a URL whose
# report id the user already has just returns that existing session.
#
#   result = TrackmanIngestor.call(user: current_user, url: params[:url])
#   if result.error
#     ...
#   else
#     result.session       # the TrackmanSession (existing or newly created)
#     result.created?      # false if it already existed
#   end
#
# TrackmanIngestor.refresh!(session) re-fetches an existing session from its
# own stored source_url and replaces its shots -- used to backfill new Shot
# columns (or corrected units) into sessions ingested before they existed,
# without the user re-pasting anything.
class TrackmanIngestor
  Result = Struct.new(:session, :created, :error, keyword_init: true) do
    def created?
      !!created
    end

    def ok?
      error.nil?
    end
  end

  def self.call(...) = new(...).call

  def self.refresh!(session, client: TrackmanReport::Client.new)
    user = session.user
    report = client.fetch_report(session.source_url)
    rows = TrackmanReport::Parser.parse(report)
    rows = rows.select { |r| r["player_name"] == user.player_name } if user.player_name.present?
    rows = rows.reject { |r| r["club"].to_s.strip.empty? }
    return Result.new(error: "No shots found on refresh") if rows.empty?

    ActiveRecord::Base.transaction do
      session.shots.delete_all
      now = Time.current
      Shot.insert_all!(rows.map { |row| shot_attrs(session, row, now) })
      session.update!(shot_count: rows.size, fetched_at: now)
    end
    Result.new(session: session.reload, created: false)
  rescue TrackmanReport::Error => e
    Result.new(error: e.message)
  end

  def self.shot_attrs(session, row, now)
    {
      trackman_session_id: session.id,
      club: row["club"],
      shot_number: row["shot_number"],
      session_shot_number: row["session_shot_number"],
      total: row["measurement_total_yd"],
      total_side: row["measurement_total_side_yd"],
      carry: row["measurement_carry_yd"],
      smash_factor: row["measurement_smash_factor"],
      club_speed: row["measurement_club_speed_mph"],
      ball_speed: row["measurement_ball_speed_mph"],
      face_to_path: row["measurement_face_to_path"],
      club_path: row["measurement_club_path"],
      face_angle: row["measurement_face_angle"],
      attack_angle: row["measurement_attack_angle"],
      raw: row.to_json,
      created_at: now,
      updated_at: now
    }
  end

  def initialize(user:, url:, client: TrackmanReport::Client.new)
    @user = user
    @url = url.to_s.strip
    @client = client
  end

  def call
    report_id = extract_report_id(@url)
    return failure(@url_error) unless report_id

    existing = @user.trackman_sessions.find_by(report_id: report_id)
    return Result.new(session: existing, created: false) if existing

    report = @client.fetch_report(@url)
    rows = TrackmanReport::Parser.parse(report)
    rows = rows.select { |r| r["player_name"] == @user.player_name } if @user.player_name.present?
    rows = rows.reject { |r| r["club"].to_s.strip.empty? }

    if rows.empty?
      scope_note = @user.player_name.present? ? " for player \"#{@user.player_name}\"" : ""
      return failure("That report has no shots#{scope_note}.")
    end

    Result.new(session: persist(report_id, rows), created: true)
  rescue TrackmanReport::Error => e
    failure(e.message)
  end

  private

  def persist(report_id, rows)
    first = rows.first
    session = nil

    ActiveRecord::Base.transaction do
      session = @user.trackman_sessions.create!(
        report_id: report_id,
        source_url: @url,
        session_date: first["group_date"],
        facility: first["group_facility_2_name"] || first["group_location_name"],
        bay: first["group_bay_name"],
        player_name: first["player_name"],
        shot_count: rows.size,
        fetched_at: Time.current
      )

      now = Time.current
      Shot.insert_all!(rows.map { |row| self.class.shot_attrs(session, row, now) })
    end

    session
  end

  # Delegates to the client's own URL parsing (which understands both `r`/
  # `ReportId` report links and `a` activity links) rather than duplicating
  # it, so "does this URL have an id" and "which id did we actually fetch"
  # can never disagree.
  def extract_report_id(url)
    id, = @client.parse_url(url)
    id
  rescue TrackmanReport::InvalidUrlError => e
    @url_error = e.message
    nil
  end

  def failure(message) = Result.new(error: message)
end
