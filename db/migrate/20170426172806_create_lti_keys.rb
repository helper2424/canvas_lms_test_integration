class CreateLtiKeys < ActiveRecord::Migration[5.0]
  def change
    create_table :lti_keys do |t|
      t.string :key, null: false
      t.string :secret, null: false

      t.index :key, unique: true
      t.timestamps
    end
  end
end
