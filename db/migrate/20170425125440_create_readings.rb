class CreateReadings < ActiveRecord::Migration[5.0]
  def change
    create_table :readings do |t|
      t.string :uid, null: false
      t.string :readings, null: false
      t.timestamps
    end
  end
end
