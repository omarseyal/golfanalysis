class CreateTrackmanSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :trackman_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :report_id, null: false
      t.text :source_url, null: false
      t.date :session_date
      t.string :facility
      t.string :bay
      t.string :player_name
      t.integer :shot_count, null: false, default: 0
      t.datetime :fetched_at, null: false

      t.timestamps
    end
    add_index :trackman_sessions, %i[user_id report_id], unique: true
    add_index :trackman_sessions, :session_date
  end
end
