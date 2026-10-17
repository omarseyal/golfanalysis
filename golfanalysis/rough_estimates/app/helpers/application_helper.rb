module ApplicationHelper
  # The Clubs menu in the shared topbar, for pages other than the dashboard
  # (which builds its own from the shot data it already has). Same rules as
  # the dashboard's menu: clubs with enough shots for a drill-down page, in
  # bag order, each with the color the dashboard gives it -- its rank among
  # every club with data, cycled through the 8-color palette.
  def topbar_clubs
    counts = Shot.joins(:trackman_session)
      .where(trackman_sessions: { user_id: current_user.id })
      .where.not(club: [ nil, "" ])
      .group(:club)
      .pluck(:club, Arel.sql("COUNT(*)"), Arel.sql("COUNT(DISTINCT trackman_sessions.session_date)"))
    in_bag_order = counts.sort_by { |club, _, _| [ ClubStats::LOFT_ORDER.index(club) || -1, club ] }
    in_bag_order.each_with_index.filter_map do |(club, shots, sessions), rank|
      next if shots < ClubStats::UNLOCK_SHOTS
      { club: club, shots: shots, sessions: sessions, color: "var(--s#{rank % 8 + 1})" }
    end
  end
end
