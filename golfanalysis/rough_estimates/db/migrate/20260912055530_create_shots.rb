class CreateShots < ActiveRecord::Migration[8.1]
  def change
    create_table :shots do |t|
      t.references :trackman_session, null: false, foreign_key: true
      t.string :club
      t.integer :shot_number
      t.integer :session_shot_number

      # The handful of measurements the summary/progress views chart. Kept as
      # real columns for fast aggregation; the full row (100+ TrackMan
      # fields) is preserved untouched in `raw` for raw-data access.
      t.float :total
      t.float :total_side
      t.float :carry
      t.float :smash_factor
      t.float :club_speed
      t.float :ball_speed
      t.float :face_to_path
      t.float :club_path
      t.float :attack_angle

      t.text :raw, null: false

      t.timestamps
    end
    add_index :shots, %i[trackman_session_id club]
  end
end
