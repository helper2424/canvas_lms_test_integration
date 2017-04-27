class CreateUserParams < ActiveRecord::Migration[5.0]
  def change
    create_table :user_params do |t|
      t.integer :user, null: false
      t.string :params
      t.timestamps
    end
  end
end
