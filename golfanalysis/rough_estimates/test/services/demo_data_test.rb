require "test_helper"

class DemoDataTest < ActiveSupport::TestCase
  test "seeds a demo account with sessions spanning every configured club" do
    user = DemoData.seed!

    assert_equal DemoData::EMAIL, user.email
    assert user.authenticate(DemoData::PASSWORD)
    assert user.trackman_sessions.count.positive?

    progress = ClubProgress.build(user.trackman_sessions)
    DemoData::CLUBS.each do |club|
      assert progress.key?(club[:name]), "expected progress data for #{club[:name]}"
    end
  end

  test "each club's median distance and smash factor improve from first to last session" do
    user = DemoData.seed!
    progress = ClubProgress.build(user.trackman_sessions)

    progress.each do |club, entries|
      next if entries.size < 2

      assert entries.last[:distance][:p50] > entries.first[:distance][:p50],
        "expected #{club} distance to improve"
      assert entries.last[:smash][:p50] > entries.first[:smash][:p50],
        "expected #{club} smash factor to improve"
    end
  end

  test "seed! is idempotent: re-running resets rather than duplicating" do
    DemoData.seed!
    first_count = User.where(email: DemoData::EMAIL).first.trackman_sessions.count

    DemoData.seed!
    assert_equal 1, User.where(email: DemoData::EMAIL).count
    assert_equal first_count, User.find_by(email: DemoData::EMAIL).trackman_sessions.count
  end

  test "destroy! removes the account" do
    DemoData.seed!
    DemoData.destroy!
    refute User.exists?(email: DemoData::EMAIL)
  end
end
