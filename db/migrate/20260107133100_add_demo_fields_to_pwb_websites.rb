class AddDemoFieldsToPwbWebsites < ActiveRecord::Migration[8.1]
  def change
    change_table :pwb_websites, bulk: true do |t|
      t.boolean :demo_mode, default: false, null: false
      t.column :demo_reset_interval, :interval, default: '24 hours'
      t.datetime :demo_last_reset_at
      t.string :demo_seed_pack
    end

    add_index :pwb_websites, [:demo_mode, :shard_name]
  end
end
