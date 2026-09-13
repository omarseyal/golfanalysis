class AddFaceAngleToShots < ActiveRecord::Migration[8.1]
  def change
    add_column :shots, :face_angle, :float
  end
end
