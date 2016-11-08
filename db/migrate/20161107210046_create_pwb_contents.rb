class CreatePwbContents < ActiveRecord::Migration[5.0]
  def change
    create_table :pwb_contents do |t|
      t.string :key
      t.string :tag
      t.text :raw

      t.string :input_type
      t.string :status
      t.integer :last_updated_by_user_id

      # To allow ordering of content
      t.integer :sort_order
      t.string :target_url

      t.timestamps null: false
    end

    add_index :pwb_contents, :key, :unique => true
  end
end
