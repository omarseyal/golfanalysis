# Replaces the old percentile-chart Progress page with the per-shot
# dashboard ported from the "Rough estimates" design artifact (KDE
# distributions, dispersion ellipses, rolling mean/rate-of-change,
# confidence-interval "is it real?" view) -- all hand-rolled SVG/JS, no
# charting library. See app/views/analysis/index.html.erb.
class AnalysisController < ApplicationController
  layout false

  def index
    @data_json = AnalysisData.for_user(current_user).to_json
  end
end
