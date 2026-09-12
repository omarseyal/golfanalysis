class TrackmanSession < ApplicationRecord
  belongs_to :user
  has_many :shots, dependent: :destroy

  validates :report_id, presence: true, uniqueness: { scope: :user_id }
  validates :source_url, presence: true

  scope :chronological, -> { order(:session_date, :created_at) }

  def clubs
    shots.distinct.pluck(:club).compact.sort
  end
end
