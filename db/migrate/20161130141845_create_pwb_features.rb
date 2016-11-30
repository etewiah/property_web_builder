class CreatePwbFeatures < ActiveRecord::Migration[5.0]
  def change
    create_table :pwb_features do |t|
      t.string :feature_key
      t.integer :prop_id
      t.timestamps null: false
    end
    add_index :pwb_features, :feature_key
  end
end
