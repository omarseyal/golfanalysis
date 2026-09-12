class Shot < ApplicationRecord
  belongs_to :trackman_session

  # The full ~100-column TrackMan row for this shot, exactly as parsed —
  # the "raw data" behind the structured columns above.
  def raw_row
    JSON.parse(raw)
  end
end
