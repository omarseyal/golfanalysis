# Renders one ClubProgress metric series as a self-contained inline SVG line
# chart: a shaded P25-P75 band with a bold median line (or, for a `single:`
# metric like "% in range", just the one line), hoverable points, ported
# from script/plot_progress.rb.
module ProgressChartHelper
  CHART_W = 640
  CHART_H = 260
  PAD_L = 46
  PAD_R = 16
  PAD_T = 16
  PAD_B = 34

  def progress_chart(entries, metric, unit, decimals: 1, single: false)
    plottable = entries.select { |e| e[metric][:p50] && (single || (e[metric][:p25] && e[metric][:p75])) }
    return content_tag(:p, "Not enough data yet.", class: "empty") if plottable.size < 2

    values = plottable.flat_map { |e| e[metric].values }
    min_v = values.min
    max_v = values.max
    span = max_v - min_v
    span = 1.0 if span.zero?
    min_v -= span * 0.15
    max_v += span * 0.15
    if single
      min_v = [min_v, 0.0].max
      max_v = [max_v, 100.0].min
    end

    n = plottable.size
    plot_w = CHART_W - PAD_L - PAD_R
    plot_h = CHART_H - PAD_T - PAD_B

    x_for = ->(i) { PAD_L + (n == 1 ? plot_w / 2.0 : (plot_w * i) / (n - 1).to_f) }
    y_for = ->(v) { PAD_T + plot_h - ((v - min_v) / (max_v - min_v)) * plot_h }

    svg = +%(<svg viewBox="0 0 #{CHART_W} #{CHART_H}" class="chart" role="img" aria-label="#{ERB::Util.html_escape(metric.to_s)} progress chart">)

    4.downto(0) do |t|
      v = min_v + (max_v - min_v) * t / 4.0
      y = y_for.call(v)
      svg << %(<line x1="#{PAD_L}" y1="#{'%.1f' % y}" x2="#{CHART_W - PAD_R}" y2="#{'%.1f' % y}" class="grid"/>)
      svg << %(<text x="#{PAD_L - 8}" y="#{'%.1f' % (y + 3)}" class="ytick" text-anchor="end">#{format("%.#{decimals}f", v)}</text>)
    end

    label_every = n > 9 ? (n / 8.0).ceil : 1
    plottable.each_with_index do |e, i|
      next unless (i % label_every).zero? || i == n - 1

      x = x_for.call(i)
      svg << %(<text x="#{'%.1f' % x}" y="#{CHART_H - PAD_B + 16}" class="xtick" text-anchor="middle">#{e[:date].strftime('%m-%d')}</text>)
    end

    unless single
      upper = plottable.each_with_index.map { |e, i| [x_for.call(i), y_for.call(e[metric][:p75])] }
      lower = plottable.each_with_index.map { |e, i| [x_for.call(i), y_for.call(e[metric][:p25])] }.reverse
      band_points = (upper + lower).map { |x, y| "#{'%.1f' % x},#{'%.1f' % y}" }.join(" ")
      svg << %(<polygon points="#{band_points}" class="band"/>)

      %i[p75 p25].each do |pctl|
        pts = plottable.each_with_index.map { |e, i| "#{'%.1f' % x_for.call(i)},#{'%.1f' % y_for.call(e[metric][pctl])}" }
        svg << %(<polyline points="#{pts.join(' ')}" fill="none" class="line #{pctl}"/>)
      end
    end

    median_pts = plottable.each_with_index.map { |e, i| "#{'%.1f' % x_for.call(i)},#{'%.1f' % y_for.call(e[metric][:p50])}" }
    svg << %(<polyline points="#{median_pts.join(' ')}" fill="none" class="line p50"/>)

    pctls = single ? %i[p50] : %i[p25 p50 p75]
    pctls.each do |pctl|
      plottable.each_with_index do |e, i|
        v = e[metric][pctl]
        x = x_for.call(i)
        y = y_for.call(v)
        prefix = single ? "" : "#{pctl.to_s.upcase} "
        label = "#{e[:date]} · #{prefix}#{format("%.#{decimals}f", v)}#{unit} · #{e[:shots]} shots"
        svg << %(<circle cx="#{'%.1f' % x}" cy="#{'%.1f' % y}" r="3.2" class="dot #{pctl}"><title>#{ERB::Util.html_escape(label)}</title></circle>)
      end
    end

    svg << "</svg>"
    raw(svg)
  end
end
