namespace :demo do
  desc "Create/reset the demo account with ~2 years of synthetic progress data"
  task seed: :environment do
    user = DemoData.seed!
    puts "Seeded #{DemoData::EMAIL} / #{DemoData::PASSWORD} with #{user.trackman_sessions.count} sessions, " \
         "#{Shot.joins(:trackman_session).merge(user.trackman_sessions).count} shots."
  end

  desc "Remove the demo account and all its data"
  task destroy: :environment do
    DemoData.destroy!
    puts "Removed #{DemoData::EMAIL} (if it existed)."
  end
end
