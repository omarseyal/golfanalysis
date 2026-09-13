module TrackmanReport
  # TrackMan's dynamic-report API returns most Measurement values in SI
  # units (metres, metres/second) regardless of the report URL's own `u=`
  # display-units param -- verified against real API responses (a "35" club
  # speed is impossible as mph but a normal ~78mph as m/s).
  #
  # Total/Carry Side are the one exception: they come back in *feet*, not
  # metres, even though Total/Carry themselves are metres. Verified the same
  # way: treating a 9-iron's side as metres put its side/total ratio as high
  # as 38% (a near-90-degree mishit, implausible more than once in a
  # session) and its dispersion SD at 12+ yards; treating it as feet puts
  # the same session's ratio and SD (~4 yd) in line with normal short-iron
  # dispersion, and the pattern holds across reports fetched with different
  # `u=` display settings, meaning it isn't display-mode dependent.
  #
  # Angles (degrees) and Smash Factor (dimensionless) need no conversion.
  module Units
    M_TO_YD = 1.09361
    FT_TO_YD = 1 / 3.0
    MPS_TO_MPH = 2.23694

    module_function

    def meters_to_yards(m)
      m.nil? ? nil : m * M_TO_YD
    end

    def feet_to_yards(ft)
      ft.nil? ? nil : ft * FT_TO_YD
    end

    def mps_to_mph(v)
      v.nil? ? nil : v * MPS_TO_MPH
    end
  end
end
