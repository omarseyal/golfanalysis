module TrackmanReport
  # Recursively flattens the nested JSON structures TrackMan returns (e.g. a
  # Stroke's Measurement/NormalizedMeasurement/ImpactLocation sub-objects)
  # into a single-level Hash of snake_case column names, so new fields
  # TrackMan adds show up automatically instead of needing a hardcoded list.
  module Flatten
    module_function

    # skip_keys: original (PascalCase) key names to omit entirely, matched
    # case-insensitively anywhere in the tree (used to drop the large
    # BallTrajectory/ClubTrajectory point clouds by default).
    def call(value, prefix: nil, skip_keys: [], into: {})
      skip = skip_keys.map { |k| k.to_s.downcase }

      case value
      when Hash
        value.each do |key, v|
          next if skip.include?(key.to_s.downcase)

          column = prefix ? "#{prefix}_#{underscore(key)}" : underscore(key)
          call(v, prefix: column, skip_keys: skip_keys, into: into)
        end
      when Array
        into[prefix] = flatten_array(value)
      else
        into[prefix] = value
      end

      into
    end

    def flatten_array(array)
      return nil if array.empty?

      if array.all? { |e| e.is_a?(Numeric) || e.is_a?(String) || e.nil? }
        array.join(";")
      else
        require "json"
        JSON.generate(array)
      end
    end

    def underscore(key)
      key.to_s
        .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
        .gsub(/([a-z\d])([A-Z])/, '\1_\2')
        .gsub(/[^a-zA-Z0-9]+/, "_")
        .downcase
        .gsub(/_+/, "_")
        .gsub(/\A_|_\z/, "")
    end
  end
end
