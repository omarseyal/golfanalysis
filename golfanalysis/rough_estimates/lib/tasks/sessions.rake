namespace :sessions do
  desc "Re-fetch every real (non-demo) session from its stored source_url -- backfills new Shot columns and unit fixes into already-ingested sessions"
  task reingest_real: :environment do
    sessions = TrackmanSession.joins(:user).where.not(users: { email: DemoData::EMAIL }).order(:id)
    ok = 0
    failed = []

    sessions.find_each do |session|
      result = TrackmanIngestor.refresh!(session)
      if result.ok?
        ok += 1
        puts "[#{session.id}] #{session.session_date} #{session.facility} -> ok (#{result.session.shot_count} shots)"
      else
        failed << session
        puts "[#{session.id}] #{session.session_date} #{session.facility} -> FAILED: #{result.error}"
      end
    end

    puts "\n#{ok} refreshed, #{failed.size} failed#{" (ids: #{failed.map(&:id).join(', ')})" if failed.any?}"
  end
end
