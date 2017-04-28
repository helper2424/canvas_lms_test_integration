class CreateOauthTokens < ActiveRecord::Migration[5.0]
  def change
    create_table :oauth_tokens do |t|

      t.string :access_token, null: false
      t.string :refresh_token, null: false

      t.integer :user_id, null: false
      t.index :user_id, unique: true
    end
  end
end
