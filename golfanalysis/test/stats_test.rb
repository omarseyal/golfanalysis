require "minitest/autorun"
require_relative "../lib/trackman_report/stats"

class StatsTest < Minitest::Test
  Stats = TrackmanReport::Stats

  def test_numeric_values_skips_nils_and_blank_strings_but_keeps_floats
    rows = [{ "v" => "1.5" }, { "v" => nil }, { "v" => "" }, { "v" => 2.5 }]
    assert_equal [1.5, 2.5], Stats.numeric_values(rows, "v")
  end

  def test_mean_and_median
    assert_in_delta 2.0, Stats.mean([1, 2, 3])
    assert_equal 2, Stats.median([1, 2, 3])
    assert_in_delta 2.5, Stats.median([1, 2, 3, 4])
    assert_nil Stats.mean([])
    assert_nil Stats.median([])
  end

  def test_percentile_matches_excel_percentile_inc
    values = [1, 2, 3, 4]
    assert_in_delta 1.75, Stats.percentile(values, 25)
    assert_in_delta 2.5, Stats.percentile(values, 50)
    assert_in_delta 3.25, Stats.percentile(values, 75)
    assert_equal 5, Stats.percentile([5], 50)
    assert_nil Stats.percentile([], 50)
  end

  def test_variance_requires_at_least_two_values
    assert_nil Stats.variance([1])
    assert_in_delta 1.0, Stats.variance([1, 2, 3])
  end

  def test_pct_in_range
    assert_in_delta 50.0, Stats.pct_in_range([1, 2, 3, 4], 3, 5)
    assert_nil Stats.pct_in_range([], 0, 1)
  end
end
