module TrackmanReport
  # TrackMan's dynamic-report API returns Measurement values in SI units
  # (metres, metres/second) regardless of the report URL's own `u=` display-
  # units param -- verified against real API responses (a "35" club speed
  # is impossible as mph but a normal ~78mph as m/s). Angles (degrees) and
  # Smash Factor (dimensionless) need no conversion.
  module Units
    M_TO_YD = 1.09361
    MPS_TO_MPH = 2.23694

    module_function

    def meters_to_yards(m)
      m.nil? ? nil : m * M_TO_YD
    end

    def mps_to_mph(v)
      v.nil? ? nil : v * MPS_TO_MPH
    end
  end
end
