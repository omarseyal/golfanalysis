# A read-only token for the club stats API (GET /api/v1/clubs...), safe to
# embed in a browser game -- unlike api_key, it can't add or delete sessions.
class AddGameTokenToUsers < ActiveRecord::Migration[8.1]
  class User < ActiveRecord::Base; end

  def up
    add_column :users, :game_token, :string
    User.reset_column_information
    User.find_each { |u| u.update_columns(game_token: SecureRandom.base58(24)) }
    change_column_null :users, :game_token, false
    add_index :users, :game_token, unique: true
  end

  def down
    remove_column :users, :game_token
  end
end
