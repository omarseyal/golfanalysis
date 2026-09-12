module TrackmanReport
  # Small set of summary-statistics helpers shared by the report scripts
  # (session summaries, progress charts, etc.).
  module Stats
    module_function

    # Works whether values are raw Floats (fresh from the parser) or strings
    # (read back from a CSV), skipping nils and blank strings either way.
    def numeric_values(rows, field)
      rows.map { |r| r[field] }.compact.reject { |v| v.respond_to?(:empty?) && v.empty? }.map(&:to_f)
    end

    def mean(values)
      return nil if values.empty?

      values.sum / values.size
    end

    def median(values)
      return nil if values.empty?

      sorted = values.sort
      mid = sorted.size / 2
      sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
    end

    # Linear-interpolation percentile (matches Excel PERCENTILE.INC / numpy default).
    def percentile(values, p)
      return nil if values.empty?

      sorted = values.sort
      return sorted.first if sorted.size == 1

      rank = (p / 100.0) * (sorted.size - 1)
      lower = rank.floor
      upper = rank.ceil
      return sorted[lower] if lower == upper

      sorted[lower] + (sorted[upper] - sorted[lower]) * (rank - lower)
    end

    # Sample variance (n-1); nil when fewer than 2 values.
    def variance(values)
      return nil if values.size < 2

      m = mean(values)
      values.sum { |v| (v - m)**2 } / (values.size - 1)
    end

    def pct_in_range(values, lo, hi)
      return nil if values.empty?

      100.0 * values.count { |v| v >= lo && v <= hi } / values.size
    end
  end
end
