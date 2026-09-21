class CreatePages < ActiveRecord::Migration[8.1]
  def change
    create_table :pages do |t|
      t.text :markdown, null: false, default: ""

      t.timestamps
    end
  end
end
