# Small formatters shared by the club averages/dispersion table partials —
# same presentation script/fetch_sessions.rb uses for summary.md.
module StatsDisplayHelper
  def fmt(value, precision: 1)
    value.nil? ? "–" : format("%.#{precision}f", value)
  end

  def pct(value)
    value.nil? ? "–" : format("%.0f%%", value)
  end

  def stat_pair(hash)
    "#{fmt(hash[:mean])} / #{fmt(hash[:median])}"
  end

  def iqr_pair(hash)
    "#{fmt(hash[:p25])} – #{fmt(hash[:p75])}"
  end
end
