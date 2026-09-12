class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :name
      # Exact TrackMan player name to keep when a report contains more than
      # one golfer's shots (e.g. a shared bay). Blank means "keep everyone".
      t.string :player_name
      t.string :api_key, null: false

      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :api_key, unique: true
  end
end
