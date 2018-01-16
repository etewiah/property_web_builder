class CreatePwbMessages < ActiveRecord::Migration[5.0]
  def change
    create_table :pwb_messages do |t|
      t.string :title
      t.text :content
      t.integer :client_id
      t.string :origin_ip
      t.string :user_agent
      t.float :longitude
      t.float :latitude
      t.string :locale
      t.string :host
      t.string :url
      t.boolean :delivery_success, default: false
      t.string :delivery_email
      t.string :origin_email

      t.timestamps null: false
    end
  end
end

