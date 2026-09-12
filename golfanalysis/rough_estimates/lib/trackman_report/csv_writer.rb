require "csv"

module TrackmanReport
  module CsvWriter
    module_function

    # Writes an array of row Hashes (as returned by Parser#rows) to CSV.
    # Column order: club/shot_number first, then every other key seen
    # across all rows (rows may have different keys, e.g. a putter has no
    # SpinAxis) sorted alphabetically for stability, missing values blank.
    def write(rows, path_or_io)
      columns = ordered_columns(rows)

      csv_string = CSV.generate do |csv|
        csv << columns
        rows.each { |row| csv << columns.map { |c| row[c] } }
      end

      case path_or_io
      when String
        File.write(path_or_io, csv_string)
      else
        path_or_io.write(csv_string)
      end
    end

    def ordered_columns(rows)
      leading = %w[club shot_number session_shot_number]
      all_keys = rows.flat_map(&:keys).uniq
      leading.select { |c| all_keys.include?(c) } + (all_keys - leading).sort
    end
  end
end
